// The toolbar popup: the most recent things waiting on you, by tab, and a way to the rest.

const TABS = ["issues", "pulls", "activity"];
const DEFAULT_SHOWN = 5;

const body = document.getElementById("body");
const meta = document.getElementById("meta");
const checkButton = document.getElementById("check");
const allButton = document.getElementById("all");
const githubLink = document.getElementById("github");
const segments = document.getElementById("segments");
const thumb = document.getElementById("thumb");

let status = null;
let checking = false;
let tab = "issues";
try { tab = TABS.includes(localStorage.getItem("tab")) ? localStorage.getItem("tab") : tab; } catch (_) { /* no storage */ }

function relative(iso) {
    const minutes = Math.round((Date.now() - Date.parse(iso)) / 60000);
    if (minutes < 1) return "now";
    if (minutes < 60) return `${minutes}m`;
    const hours = Math.round(minutes / 60);
    if (hours < 24) return `${hours}h`;
    const days = Math.round(hours / 24);
    if (days < 30) return `${days}d`;
    return new Date(iso).toLocaleDateString(undefined, { month: "short", day: "numeric" });
}

function isStale(summary) {
    if (!summary?.checkedAt) return true;
    const interval = (summary.checkIntervalMinutes || 1) * 60 * 1000;
    return Date.now() - Date.parse(summary.checkedAt) > interval * 3 + 60 * 1000;
}

function el(tag, className, text) {
    const node = document.createElement(tag);
    if (className) node.className = className;
    if (text !== undefined) node.textContent = text;
    return node;
}

async function open(url) {
    await browser.tabs.create({ url });
    window.close();
}

function state(kind, title, text) {
    const box = el("div", `state ${kind}`);
    box.appendChild(el("strong", "", title));
    if (text) box.appendChild(el("span", "", text));
    return box;
}

function row(item) {
    const button = el("button", "row");
    button.type = "button";
    button.title = item.title;
    button.appendChild(el("span", `dot ${item.kind}`));

    const text = el("div");
    const title = el("div", "title", item.title);
    if (item.isDraft) title.appendChild(el("span", "draft", "Draft"));
    text.appendChild(title);
    const sub = el("div", "sub");
    sub.appendChild(statusTag(item));
    sub.appendChild(el("span", "where", whereText(item)));
    text.appendChild(sub);
    button.appendChild(text);

    button.appendChild(el("span", "when", relative(item.updatedAt)));
    button.addEventListener("click", () => open(item.url));
    return button;
}

// Which items each tab lists. Activity is anything with unread notifications, whatever it is.
function itemsFor(name, items) {
    switch (name) {
        case "issues": return items.filter((i) => i.subject === "issue");
        case "pulls": return items.filter((i) => i.subject === "pullRequest");
        case "activity": return items.filter((i) => i.hasUnread || i.kind === "notification");
        default: return items;
    }
}

const EMPTY = {
    issues: ["No issues", "Nothing assigned or waiting on you."],
    pulls: ["No pull requests", "Nothing to review and nothing of yours is open."],
    activity: ["No unread activity", "No new comments, mentions or changes."],
};

function selectTab(name, animate = true) {
    tab = name;
    try { localStorage.setItem("tab", name); } catch (_) { /* no storage */ }
    const index = TABS.indexOf(name);
    thumb.style.transition = animate ? "" : "none";
    thumb.style.transform = `translateX(${index * 100}%)`;
    for (const button of segments.querySelectorAll("[data-tab]")) {
        button.setAttribute("aria-selected", button.dataset.tab === name ? "true" : "false");
    }
}

function renderList(items, shown) {
    body.replaceChildren();
    const visible = itemsFor(tab, items);
    if (visible.length === 0) {
        const [title, text] = EMPTY[tab];
        body.appendChild(state(items.length === 0 ? "ok" : "", title, text));
        return;
    }
    visible.slice(0, shown).forEach((item, index) => {
        const node = row(item);
        node.style.setProperty("--i", String(index));
        body.appendChild(node);
    });
}

function render() {
    body.replaceChildren();
    const summary = status?.summary;

    if (!status || !status.available) {
        meta.textContent = "App not reachable";
        body.appendChild(state("", "GitIt isn't running", "Open GitIt from ~/Applications; it does the checking."));
        allButton.hidden = true;
        segments.hidden = true;
        return;
    }
    if (!status.hasToken) {
        meta.textContent = "No token";
        body.appendChild(state("", "Add a token", "Paste a GitHub personal access token in GitIt's settings."));
        allButton.hidden = true;
        segments.hidden = true;
        return;
    }
    if (!summary) {
        meta.textContent = "First check pending";
        body.appendChild(state("", "Checking GitHub…", ""));
        allButton.hidden = true;
        segments.hidden = true;
        return;
    }

    const items = summary.items || [];
    const shown = summary.popupItemCount || DEFAULT_SHOWN;
    meta.textContent = isStale(summary)
        ? `Last checked ${relative(summary.checkedAt)} ago · is GitIt running?`
        : `${items.length === 1 ? "1 item needs" : `${items.length} items need`} you · checked ${relative(summary.checkedAt)} ago`;

    segments.hidden = false;
    for (const badge of segments.querySelectorAll("[data-n]")) {
        const n = itemsFor(badge.dataset.n, items).length;
        badge.textContent = String(n);
        badge.classList.toggle("zero", n === 0);
    }
    allButton.hidden = false;
    allButton.textContent = items.length > 0 ? `See all ${items.length}` : "Open dashboard";

    selectTab(tab, false);
    renderList(items, shown);
}

async function load(type) {
    try {
        status = await browser.runtime.sendMessage({ type });
    } catch (error) {
        status = { available: false, error: String(error) };
    }
    render();
}

const wait = (ms) => new Promise((resolve) => setTimeout(resolve, ms));

async function openDashboard() {
    await browser.runtime.sendMessage({ type: "openDashboard" });
    window.close();
}

segments.addEventListener("click", (event) => {
    const button = event.target.closest("[data-tab]");
    if (!button || button.dataset.tab === tab) return;
    selectTab(button.dataset.tab);
    const summary = status?.summary;
    if (summary) {
        body.classList.remove("swap");
        void body.offsetWidth; // restart the fade
        body.classList.add("swap");
        renderList(summary.items || [], summary.popupItemCount || DEFAULT_SHOWN);
    }
});

document.addEventListener("keydown", (event) => {
    if (event.key === "Escape") { window.close(); return; }
    if (event.key === "ArrowLeft" || event.key === "ArrowRight") {
        const index = TABS.indexOf(tab);
        const next = TABS[(index + (event.key === "ArrowRight" ? 1 : TABS.length - 1)) % TABS.length];
        segments.querySelector(`[data-tab="${next}"]`)?.click();
    }
});

checkButton.addEventListener("click", async () => {
    if (checking) return;
    checking = true;
    checkButton.disabled = true;
    checkButton.classList.add("spinning");
    const before = status?.summary?.checkedAt;
    await load("refresh");
    // The app checks on its own clock; wait for a newer result, up to ~8 s.
    for (let i = 0; i < 4; i++) {
        await wait(2000);
        await load("status");
        if (status?.summary?.checkedAt && status.summary.checkedAt !== before) break;
    }
    checkButton.classList.remove("spinning");
    checkButton.disabled = false;
    checking = false;
});

allButton.addEventListener("click", openDashboard);

githubLink.addEventListener("click", (event) => {
    event.preventDefault();
    open(githubLink.href);
});

// Show what the background already has, then refresh it.
load("cached").then(() => load("status"));

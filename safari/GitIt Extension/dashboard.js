// The GitIt dashboard: everything waiting on you, grouped by why.

const GROUPS = [
    { kind: "reviewRequest", title: "Review requested" },
    { kind: "notification", title: "Unread activity" },
    { kind: "assigned", title: "Assigned to you" },
    { kind: "pullRequest", title: "Your pull requests" },
];

const list = document.getElementById("list");
const meta = document.getElementById("meta");
const notice = document.getElementById("notice");
const checkButton = document.getElementById("check");
const filters = document.getElementById("filters");

let status = null;
let filter = "all";

function relative(iso) {
    const diff = Date.now() - Date.parse(iso);
    const minutes = Math.round(diff / 60000);
    if (minutes < 1) return "just now";
    if (minutes < 60) return `${minutes}m ago`;
    const hours = Math.round(minutes / 60);
    if (hours < 24) return `${hours}h ago`;
    const days = Math.round(hours / 24);
    if (days < 30) return `${days}d ago`;
    return new Date(iso).toLocaleDateString();
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

function row(item) {
    const link = el("a", "item");
    link.href = item.url;
    link.target = "_blank";
    link.rel = "noopener";

    link.appendChild(el("span", `dot ${item.kind}`));

    const body = el("div");
    const title = el("div", "item-title", item.title);
    if (item.isDraft) title.appendChild(el("span", "draft", "Draft"));
    body.appendChild(title);

    const sub = el("div", "item-sub");
    const where = item.number ? `${item.repository} #${item.number}` : item.repository;
    sub.appendChild(document.createTextNode(where));
    if (item.reason) {
        sub.appendChild(document.createTextNode(" · "));
        sub.appendChild(el("span", item.hasUnread ? "unread" : "", item.reason));
    }
    body.appendChild(sub);
    link.appendChild(body);

    link.appendChild(el("span", "when", relative(item.updatedAt)));
    return link;
}

function render() {
    list.replaceChildren();
    notice.classList.add("hidden");
    const summary = status?.summary;

    if (!status || !status.available) {
        meta.textContent = "The GitIt app cannot be reached.";
        showNotice("Open GitIt from ~/Applications. The app polls GitHub; this page only shows what it found.");
        return;
    }
    if (!status.hasToken) {
        meta.textContent = "No token yet.";
        showNotice("Add a GitHub personal access token in the GitIt app's settings.");
        return;
    }
    if (!summary) {
        meta.textContent = "Not checked yet. Is the GitIt app running?";
        return;
    }

    const items = summary.items || [];
    const who = summary.login ? `@${summary.login} · ` : "";
    meta.textContent = `${who}checked ${relative(summary.checkedAt)} · every ${summary.checkIntervalMinutes} min`;

    if (isStale(summary)) {
        showNotice("The last check is old. Make sure the GitIt app is running (it lives in the menu bar).");
    } else if (summary.errors?.length) {
        showNotice(summary.errors.join(" "));
    }

    for (const button of filters.querySelectorAll("[data-count]")) {
        const kind = button.dataset.count;
        button.textContent = String(kind === "all" ? items.length : items.filter((i) => i.kind === kind).length);
    }

    const visible = filter === "all" ? items : items.filter((i) => i.kind === filter);
    if (visible.length === 0) {
        const empty = el("div", "empty");
        empty.appendChild(el("strong", "", items.length === 0 ? "You're all caught up" : "Nothing here"));
        empty.appendChild(el("span", "", items.length === 0 ? "Nothing on GitHub is waiting on you." : "Try another filter."));
        list.appendChild(empty);
        return;
    }

    for (const group of GROUPS) {
        const rows = visible.filter((i) => i.kind === group.kind);
        if (rows.length === 0) continue;
        list.appendChild(el("h2", "group-title", `${group.title} · ${rows.length}`));
        for (const item of rows) list.appendChild(row(item));
    }
}

function showNotice(text) {
    notice.textContent = text;
    notice.classList.remove("hidden");
}

async function load(type = "status") {
    try {
        status = await browser.runtime.sendMessage({ type });
    } catch (error) {
        status = { available: false, error: String(error) };
    }
    render();
}

filters.addEventListener("click", (event) => {
    const button = event.target.closest("[data-filter]");
    if (!button) return;
    filter = button.dataset.filter;
    for (const b of filters.querySelectorAll("[data-filter]")) b.classList.toggle("active", b === button);
    render();
});

checkButton.addEventListener("click", async () => {
    checkButton.disabled = true;
    checkButton.textContent = "Checking…";
    await load("refresh");
    // The app answers the request asynchronously; pick up its result shortly after.
    setTimeout(() => load(), 4000);
    setTimeout(async () => {
        await load();
        checkButton.disabled = false;
        checkButton.textContent = "Check now";
    }, 9000);
});

browser.runtime.onMessage.addListener((message) => {
    if (message?.type === "reload") load();
});

document.addEventListener("visibilitychange", () => {
    if (document.visibilityState === "visible") load();
});

load();
setInterval(() => load(), 60000);

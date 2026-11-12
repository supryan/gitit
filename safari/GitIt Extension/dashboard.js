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
const orgSelect = document.getElementById("org");
const repoSelect = document.getElementById("repo");

let status = null;
let filter = "all";
let org = "all";
let repo = "all";
// The groups folded shut, by kind. Kept between visits.
let collapsed = new Set();
try {
    org = localStorage.getItem("org") || "all";
    repo = localStorage.getItem("repo") || "all";
    const saved = JSON.parse(localStorage.getItem("collapsed") || "[]");
    if (Array.isArray(saved)) collapsed = new Set(saved);
} catch (_) { /* no storage */ }

function remember() {
    try {
        localStorage.setItem("org", org);
        localStorage.setItem("repo", repo);
    } catch (_) { /* no storage */ }
}

const orgOf = (item) => item.repository.split("/")[0];

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
    sub.appendChild(statusTag(item));
    sub.appendChild(el("span", "where", whereText(item)));
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

    // A remembered organization or project that no longer has anything: back to all.
    if (org !== "all" && !items.some((i) => orgOf(i) === org)) org = "all";
    if (repo !== "all" && !items.some((i) => i.repository === repo && (org === "all" || orgOf(i) === org))) repo = "all";
    remember();

    // Each control counts what the other filters leave.
    const ofKind = filter === "all" ? items : items.filter((i) => i.kind === filter);
    fillSelect(orgSelect, "All orgs", items.map(orgOf), ofKind.map(orgOf), org, (name) => name);
    const inOrg = (list) => (org === "all" ? list : list.filter((i) => orgOf(i) === org));
    fillSelect(repoSelect, "All projects", inOrg(items).map((i) => i.repository), inOrg(ofKind).map((i) => i.repository), repo,
        (name) => (org === "all" ? name : name.slice(org.length + 1)));

    const scoped = inOrg(items).filter((i) => repo === "all" || i.repository === repo);
    for (const badge of filters.querySelectorAll("[data-count]")) {
        const kind = badge.dataset.count;
        badge.textContent = String(kind === "all" ? scoped.length : scoped.filter((i) => i.kind === kind).length);
    }

    const visible = filter === "all" ? scoped : scoped.filter((i) => i.kind === filter);
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
        list.appendChild(section(group, rows));
    }
}

// One group: a heading that folds it, then its rows. Built already folded or open, so the
// once-a-minute refresh never replays the animation.
function section(group, rows) {
    const box = el("section", "group");
    box.dataset.kind = group.kind;
    box.classList.toggle("collapsed", collapsed.has(group.kind));

    const heading = el("h2", "group-heading");
    const toggle = el("button", "group-title");
    toggle.type = "button";
    toggle.setAttribute("aria-expanded", String(!collapsed.has(group.kind)));
    toggle.setAttribute("aria-controls", `group-${group.kind}`);
    toggle.title = "Collapse or expand · Option-click for every section";
    toggle.appendChild(el("span", `dot ${group.kind}`));
    const label = el("span", "", group.title);
    label.appendChild(el("span", "count", String(rows.length)));
    toggle.appendChild(label);
    toggle.insertAdjacentHTML("beforeend", CHEVRON);
    toggle.addEventListener("click", (event) => {
        const fold = !collapsed.has(group.kind);
        const kinds = event.altKey ? GROUPS.map((g) => g.kind) : [group.kind];
        for (const kind of kinds) setCollapsed(kind, fold);
    });
    heading.appendChild(toggle);
    box.appendChild(heading);

    const body = el("div", "group-rows");
    body.id = `group-${group.kind}`;
    const inner = el("div", "group-inner");
    for (const item of rows) inner.appendChild(row(item));
    body.appendChild(inner);
    box.appendChild(body);
    return box;
}

const CHEVRON = '<svg class="group-chevron" viewBox="0 0 16 16" width="14" height="14" aria-hidden="true"><path fill="none" stroke="currentColor" stroke-width="1.6" stroke-linecap="round" stroke-linejoin="round" d="m4.5 6 3.5 3.5L11.5 6"/></svg>';

function setCollapsed(kind, fold) {
    if (fold) collapsed.add(kind);
    else collapsed.delete(kind);
    try { localStorage.setItem("collapsed", JSON.stringify([...collapsed])); } catch (_) { /* no storage */ }
    const box = list.querySelector(`.group[data-kind="${kind}"]`);
    if (!box) return;
    box.classList.toggle("collapsed", fold);
    box.querySelector(".group-title").setAttribute("aria-expanded", String(!fold));
}

// Rebuilds a dropdown: `allLabel`, then every name in `names`, most items first, each with
// how many of `counted` it has. Leaves it alone when nothing changed, so an open menu
// is not yanked away by the once-a-minute refresh.
function fillSelect(select, allLabel, names, counted, selected, label) {
    const counts = new Map();
    for (const name of new Set(names)) counts.set(name, 0);
    for (const name of counted) counts.set(name, (counts.get(name) || 0) + 1);
    const sorted = [...counts.entries()].sort((a, b) => b[1] - a[1] || a[0].localeCompare(b[0]));
    const options = [["all", `${allLabel} · ${counted.length}`], ...sorted.map(([name, n]) => [name, `${label(name)} · ${n}`])];
    const key = JSON.stringify(options);
    if (select.dataset.key !== key) {
        select.replaceChildren(...options.map(([value, text]) => {
            const option = document.createElement("option");
            option.value = value;
            option.textContent = text;
            return option;
        }));
        select.dataset.key = key;
    }
    select.value = selected;
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

orgSelect.addEventListener("change", () => {
    org = orgSelect.value;
    repo = "all";
    remember();
    render();
});

repoSelect.addEventListener("change", () => {
    repo = repoSelect.value;
    remember();
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

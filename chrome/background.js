// GitIt's background service worker for Chrome: asks the GitIt app for its latest result,
// keeps the toolbar badge in step, and opens the dashboard for the popup.
//
// The popup and dashboard pages come from shared/, copied in by build.sh; only
// this file and the manifest are Chrome's own. The app does all the GitHub work through
// its native messaging host (app/GitIt/ChromeNativeHost.swift): this never holds the
// token and never calls GitHub.

const HOST = "com.gitit.app";
const ALARM = "gitit-refresh";
const DASHBOARD = chrome.runtime.getURL("dashboard.html");
const EMPTY = { available: false, hasToken: false, summary: null };

// Chrome stops idle service workers, so the last answer also lives in session storage
// for the popup's instant first paint.
let status = null;

async function cached() {
    if (status) return status;
    const stored = await chrome.storage.session.get("status");
    status = stored.status || EMPTY;
    return status;
}

async function ask(type) {
    try {
        status = await chrome.runtime.sendNativeMessage(HOST, { type });
    } catch (error) {
        console.error("GitIt: native message failed", error);
        status = { ...EMPTY, error: String(error?.message || error) };
    }
    await chrome.storage.session.set({ status, at: Date.now() });
    await updateBadge();
    if (status?.openDashboard) {
        // The app's Dashboard button chose Chrome: it cannot open this page itself.
        status.openDashboard = false;
        openDashboard();
    }
    return status;
}

function isStale(summary) {
    if (!summary?.checkedAt) return true;
    const age = Date.now() - Date.parse(summary.checkedAt);
    const interval = (summary.checkIntervalMinutes || 1) * 60 * 1000;
    return age > interval * 3 + 60 * 1000;
}

async function updateBadge() {
    const summary = status?.summary;
    let text = "";
    let title = "GitIt";
    if (!status?.available) {
        title = "GitIt: the GitIt app cannot be reached";
    } else if (!status.hasToken) {
        title = "GitIt: add a personal access token in the GitIt app";
    } else if (!summary) {
        title = "GitIt: not checked yet";
    } else {
        const total = summary.items?.length ?? 0;
        text = total > 0 ? (total > 999 ? "999+" : String(total)) : "";
        title = total === 0 ? "GitIt: all caught up" : `GitIt: ${total} item${total === 1 ? "" : "s"} need your attention`;
        if (isStale(summary)) title += " (last check is old; is the GitIt app running?)";
    }
    try {
        await chrome.action.setBadgeText({ text });
        // The popup's badge red (theme.css --badge).
        await chrome.action.setBadgeBackgroundColor({ color: "#ef4444" });
        await chrome.action.setBadgeTextColor({ color: "#ffffff" });
        await chrome.action.setTitle({ title });
    } catch (error) {
        console.error("GitIt: badge", error);
    }
}


async function openDashboard() {
    const tabs = await chrome.tabs.query({ url: `${DASHBOARD}*` });
    if (tabs.length > 0) {
        const tab = tabs[0];
        await chrome.tabs.update(tab.id, { active: true });
        await chrome.windows.update(tab.windowId, { focused: true });
        chrome.tabs.sendMessage(tab.id, { type: "reload" }).catch(() => {});
    } else {
        await chrome.tabs.create({ url: DASHBOARD });
    }
}

function handle(message) {
    switch (message?.type) {
        case "openDashboard": return openDashboard();
        case "status": return ask("status");
        case "refresh": return ask("refresh");
        case "cached": return cached();
        default: return null;
    }
}

// The popup and dashboard ask through here. Chrome wants replies via sendResponse, with
// `return true` to keep the channel open while the answer is on its way.
chrome.runtime.onMessage.addListener((message, _sender, sendResponse) => {
    const work = handle(message);
    if (!work) return false;
    Promise.resolve(work).then(sendResponse, (error) => sendResponse({ ...EMPTY, error: String(error) }));
    return true;
});

// The app brings Chrome forward after leaving a Dashboard request; a window gaining
// focus wakes this worker, and the status answer carries the request.
chrome.windows.onFocusChanged.addListener((windowId) => {
    if (windowId !== chrome.windows.WINDOW_ID_NONE) ask("status");
});

chrome.alarms.onAlarm.addListener((alarm) => {
    if (alarm.name === ALARM) ask("status");
});

async function schedule() {
    const existing = await chrome.alarms.get(ALARM);
    if (!existing) await chrome.alarms.create(ALARM, { delayInMinutes: 0.5, periodInMinutes: 1 });
}

const wait = (ms) => new Promise((resolve) => setTimeout(resolve, ms));

// Whenever this worker starts (installed, enabled, Chrome launched, or woken by an event):
// fetch unless the last answer is fresh, and if the app did not answer, try again a few
// times before leaving it to the alarm, so the badge fills in without opening the popup.
// Enabling the extension fires neither onInstalled nor onStartup, hence running here.
async function startUp() {
    await schedule();
    const { status: last, at } = await chrome.storage.session.get(["status", "at"]);
    if (last?.available && at && Date.now() - at < 30_000) {
        status = last;
        return;
    }
    for (const delay of [0, 2000, 5000, 10000]) {
        if (delay) await wait(delay);
        await ask("status");
        if (status?.available) return;
    }
}

startUp();

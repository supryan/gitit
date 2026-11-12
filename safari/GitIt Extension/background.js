// GitIt's background script: asks the native handler for the app's latest summary,
// keeps the toolbar badge in step, and opens the dashboard for the popup.
//
// The app does all the GitHub work. This never holds the token and never calls GitHub.

const NATIVE_APP = "com.jickfive.gitit"; // Safari ignores the id; it is the containing app.
const ALARM = "gitit-refresh";
const DASHBOARD = browser.runtime.getURL("dashboard.html");

let status = { available: false, hasToken: false, summary: null };

async function refresh() {
    try {
        status = await browser.runtime.sendNativeMessage(NATIVE_APP, { type: "status", dashboard: DASHBOARD });
    } catch (error) {
        console.error("GitIt: native message failed", error);
        status = { available: false, hasToken: false, summary: null, error: String(error) };
    }
    await updateBadge();
    takeDashboardRequest();
    return status;
}

async function requestCheckNow() {
    try {
        status = await browser.runtime.sendNativeMessage(NATIVE_APP, { type: "refresh", dashboard: DASHBOARD });
    } catch (error) {
        console.error("GitIt: native message failed", error);
    }
    await updateBadge();
    takeDashboardRequest();
    return status;
}

// The app's Dashboard button: Safari will not open this page for the app, so the app
// leaves a request that arrives with the next status answer, and this opens it.
function takeDashboardRequest() {
    if (!status?.openDashboard) return;
    status.openDashboard = false;
    openDashboard();
}

function isStale(summary) {
    if (!summary?.checkedAt) return true;
    const age = Date.now() - Date.parse(summary.checkedAt);
    const interval = (summary.checkIntervalMinutes || 1) * 60 * 1000;
    return age > interval * 3 + 60 * 1000;
}

async function updateBadge() {
    const summary = status.summary;
    let text = "";
    let title = "GitIt";
    if (!status.available) {
        title = "GitIt: the GitIt app cannot be reached";
    } else if (!status.hasToken) {
        title = "GitIt: add a personal access token in the GitIt app";
    } else if (!summary) {
        title = "GitIt: not checked yet";
    } else {
        const total = summary.items?.length ?? 0;
        text = total > 0 ? String(total) : "";
        title = total === 0 ? "GitIt: all caught up" : `GitIt: ${total} item${total === 1 ? "" : "s"} need your attention`;
        if (isStale(summary)) title += " (last check is old; is the GitIt app running?)";
    }
    try {
        await browser.action.setBadgeText({ text });
        await browser.action.setTitle({ title });
    } catch (error) {
        console.error("GitIt: badge", error);
    }
}

async function openDashboard() {
    const tabs = await browser.tabs.query({ url: `${DASHBOARD}*` });
    if (tabs.length > 0) {
        const tab = tabs[0];
        await browser.tabs.update(tab.id, { active: true });
        if (tab.windowId !== undefined) {
            try { await browser.windows.update(tab.windowId, { focused: true }); } catch (_) { /* no windows API */ }
        }
        browser.tabs.sendMessage(tab.id, { type: "reload" }).catch(() => {});
    } else {
        await browser.tabs.create({ url: DASHBOARD });
    }
}

// The button opens popup.html; the popup asks for the dashboard from there.
browser.runtime.onMessage.addListener((message) => {
    switch (message?.type) {
        case "openDashboard":
            return openDashboard();
        case "status":
            return refresh();
        case "refresh":
            return requestCheckNow();
        case "cached":
            return Promise.resolve(status);
        default:
            return undefined;
    }
});

// The app brings Safari forward after leaving a Dashboard request; a window gaining
// focus wakes this script, and the status answer carries the request.
browser.windows.onFocusChanged.addListener((windowId) => {
    if (windowId !== browser.windows.WINDOW_ID_NONE) refresh();
});

browser.alarms.onAlarm.addListener((alarm) => {
    if (alarm.name === ALARM) refresh();
});

async function schedule() {
    const existing = await browser.alarms.get(ALARM);
    if (!existing) browser.alarms.create(ALARM, { periodInMinutes: 1 });
}

browser.runtime.onInstalled.addListener(() => { schedule(); refresh(); });
browser.runtime.onStartup.addListener(() => { schedule(); refresh(); });
schedule();
refresh();

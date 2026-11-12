// Shared by the popup and the dashboard: the tag that says why an item needs you.

const STATUS_LABELS = {
    reviewRequest: "Review",
    assigned: "Assigned",
    pullRequest: "Your PR",
    notification: "Activity",
};

// Unread activity names what happened ("New comment", in the unread colour); otherwise
// the tag names the item's status, in that status's colour.
function statusTag(item) {
    const tag = document.createElement("span");
    if (item.hasUnread && item.reason) {
        tag.className = "tag unread";
        tag.textContent = item.reason;
    } else {
        tag.className = `tag ${item.kind}`;
        tag.textContent = STATUS_LABELS[item.kind] || item.reason || "";
    }
    return tag;
}

// "owner/repo #123", the part of a row's second line after the tag.
function whereText(item) {
    return item.number ? `${item.repository} #${item.number}` : item.repository;
}

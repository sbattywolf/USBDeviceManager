window.logsScroll = {
    // unconditionally scroll to bottom
    scrollToBottom: function (id) {
        try {
            var el = document.getElementById(id);
            if (!el) return;
            el.scrollTop = el.scrollHeight;
        } catch (e) {
            console && console.error && console.error('logsScroll.scrollToBottom', e);
        }
    },
    // only scroll if the user is near the bottom (within threshold px)
    scrollIfNearBottom: function (id, thresholdPx) {
        try {
            var el = document.getElementById(id);
            if (!el) return;
            var distanceFromBottom = el.scrollHeight - (el.scrollTop + el.clientHeight);
            if (distanceFromBottom <= (thresholdPx || 100)) {
                el.scrollTop = el.scrollHeight;
            }
        } catch (e) {
            console && console.error && console.error('logsScroll.scrollIfNearBottom', e);
        }
    }
};

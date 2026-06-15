(function () {
	'use strict';

	function qs(sel, root) { return (root || document).querySelector(sel); }
	function qsa(sel, root) { return Array.prototype.slice.call((root || document).querySelectorAll(sel)); }

	// ── mobile nav burger ──
	var burger = qs('#fp-nav-burger');
	var menu = qs('#fp-nav-menu');
	if (burger && menu) {
		burger.addEventListener('click', function () {
			menu.classList.toggle('fp-nav-menu--open');
		});
	}

	// ── saved roles (localStorage) ──
	var SAVED_KEY = 'fp-saved-roles';

	function getSaved() {
		try {
			var raw = window.localStorage.getItem(SAVED_KEY);
			var ids = raw ? JSON.parse(raw) : [];
			return Array.isArray(ids) ? ids : [];
		} catch (e) {
			return [];
		}
	}

	function setSaved(ids) {
		try {
			window.localStorage.setItem(SAVED_KEY, JSON.stringify(ids));
		} catch (e) { /* ignore */ }
	}

	function updateSavedCount(ids) {
		var counter = qs('#nav-saved-count');
		if (counter) counter.textContent = String(ids.length);
	}

	function syncToggleStates(ids) {
		qsa('.fp-save-toggle').forEach(function (btn) {
			var id = btn.getAttribute('data-job-id');
			btn.classList.toggle('fp-save--on', ids.indexOf(id) !== -1);
		});
	}

	var savedIds = getSaved();
	updateSavedCount(savedIds);
	syncToggleStates(savedIds);

	qsa('.fp-save-toggle').forEach(function (btn) {
		btn.addEventListener('click', function (evt) {
			evt.preventDefault();
			evt.stopPropagation();
			var id = btn.getAttribute('data-job-id');
			if (!id) return;
			var ids = getSaved();
			var idx = ids.indexOf(id);
			if (idx === -1) {
				ids.push(id);
			} else {
				ids.splice(idx, 1);
			}
			setSaved(ids);
			updateSavedCount(ids);
			syncToggleStates(ids);
		});
	});
})();

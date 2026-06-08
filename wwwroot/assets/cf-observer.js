(function () {
	'use strict';

	function qs(sel, root) { return (root || document).querySelector(sel); }
	function qsa(sel, root) { return Array.prototype.slice.call((root || document).querySelectorAll(sel)); }

	// Master-detail job feed
	var cards = qsa('.job-card');
	var detailTitle = qs('#detail-title');
	var detailMeta = qs('#detail-meta');
	var detailDesc = qs('#detail-description');
	var detailInsight = qs('#detail-insight');
	var detailApply = qs('#detail-apply');
	var detailPane = qs('#detail-pane');

	function selectJob(card) {
		if (!card) return;
		cards.forEach(function (c) { c.classList.remove('active'); });
		card.classList.add('active');
		if (detailTitle) detailTitle.textContent = card.getAttribute('data-title') || '';
		if (detailMeta) detailMeta.innerHTML = card.getAttribute('data-meta') || '';
		if (detailDesc) detailDesc.textContent = card.getAttribute('data-description') || '';
		if (detailInsight) detailInsight.textContent = card.getAttribute('data-insight') || '';
		if (detailApply) {
			var link = card.getAttribute('data-link') || '';
			if (link) {
				detailApply.href = link;
				detailApply.classList.remove('opacity-50', 'pointer-events-none');
			} else {
				detailApply.href = '#';
				detailApply.classList.add('opacity-50', 'pointer-events-none');
			}
		}
		if (detailPane) {
			detailPane.style.opacity = '0';
			setTimeout(function () {
				detailPane.style.transition = 'opacity 0.3s ease';
				detailPane.style.opacity = '1';
			}, 50);
		}
	}

	cards.forEach(function (card) {
		card.addEventListener('click', function () { selectJob(card); });
	});
	if (cards.length) selectJob(cards[0]);

	// India-eligible toggle -> navigate with min_score=70
	var indiaToggle = qs('#toggle-india-eligible');
	if (indiaToggle) {
		indiaToggle.addEventListener('click', function () {
			var url = indiaToggle.getAttribute('data-on-url');
			var off = indiaToggle.getAttribute('data-off-url');
			var on = indiaToggle.getAttribute('aria-checked') === 'true';
			window.location.href = on ? off : url;
		});
	}

	// Scoring accordion
	var scoringToggle = qs('#scoring-toggle');
	var scoringPanel = qs('#scoring-panel');
	if (scoringToggle && scoringPanel) {
		scoringToggle.addEventListener('click', function () {
			scoringPanel.classList.toggle('hidden');
		});
	}
})();

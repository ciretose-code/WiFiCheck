(function () {
    var script = document.currentScript;
    var repo = script && script.getAttribute('data-repo');
    if (!repo) return;

    var useIframe = !!window.chrome;

    function tryDeepLink(url, onLaunched, onUnavailable) {
        var launched = false;

        function onBlur() {
            launched = true;
            window.removeEventListener('blur', onBlur);
            onLaunched();
        }

        window.addEventListener('blur', onBlur);
        if (useIframe) {
            var frame = document.createElement('iframe');
            frame.style.cssText = 'display:none';
            document.body.appendChild(frame);
            frame.src = url;
            setTimeout(function () {
                frame.remove();
                window.removeEventListener('blur', onBlur);
                if (!launched) onUnavailable();
            }, 1000);
        } else {
            window.location.href = url;
            setTimeout(function () {
                window.removeEventListener('blur', onBlur);
                if (!launched) onUnavailable();
            }, 1000);
        }
    }

    function digestHash(asset) {
        if (!asset || !asset.digest) return null;
        var match = String(asset.digest).match(/^sha256:([0-9a-fA-F]{64})$/i);
        return match ? match[1].toLowerCase() : null;
    }

    function findDownload(assets) {
        return (assets || []).find(function (asset) {
            return /\.dmg$/i.test(asset.name);
        }) || (assets || []).find(function (asset) {
            return !/\.sha256$/i.test(asset.name);
        });
    }

    function findHash(release, download) {
        var fromDigest = digestHash(download);
        if (fromDigest) return Promise.resolve(fromDigest);

        var match = (release.body || '').match(/\b([0-9a-fA-F]{64})\b/);
        if (match) return Promise.resolve(match[1].toLowerCase());

        var checksum = (release.assets || []).find(function (asset) {
            return /\.sha256$/i.test(asset.name);
        });
        if (checksum) {
            return fetch(checksum.browser_download_url)
                .then(function (response) { return response.text(); })
                .then(function (text) {
                    var found = text.match(/([0-9a-fA-F]{64})/);
                    return found ? found[1].toLowerCase() : null;
                });
        }

        return Promise.resolve(null);
    }

    function showVerify(hash, version) {
        var section = document.getElementById('verify-section');
        var button = document.getElementById('verify-btn');
        var hashElement = document.getElementById('sha256-display');
        var statusElement = document.getElementById('verify-status');
        var missingElement = document.getElementById('hc-missing');
        var versionElement = document.getElementById('verify-version');
        if (!section || !button || !hashElement) return;

        button.href = 'hashcheck://hash/sha256/' + hash;
        hashElement.textContent = hash;
        if (versionElement) versionElement.textContent = version || '';
        section.hidden = false;

        button.addEventListener('click', function (event) {
            event.preventDefault();
            if (statusElement) {
                statusElement.textContent = 'Launching...';
                statusElement.className = 'verify-status';
            }
            if (missingElement) missingElement.hidden = true;
            tryDeepLink(
                button.href,
                function () {
                    if (statusElement) {
                        statusElement.textContent = 'Launched';
                        statusElement.className = 'verify-status ok';
                    }
                },
                function () {
                    if (statusElement) statusElement.textContent = '';
                    if (missingElement) missingElement.hidden = false;
                }
            );
        });
    }

    fetch('https://api.github.com/repos/' + repo + '/releases/latest')
        .then(function (response) { return response.json(); })
        .then(function (release) {
            var download = findDownload(release.assets);
            var downloadButton = document.getElementById('download-btn');
            if (download && downloadButton) {
                downloadButton.href = download.browser_download_url;
                downloadButton.setAttribute('download', download.name);
            }
            return findHash(release, download).then(function (hash) {
                if (hash) showVerify(hash, release.tag_name);
            });
        })
        .catch(function () { /* keep the GitHub latest-release fallback */ });
}());

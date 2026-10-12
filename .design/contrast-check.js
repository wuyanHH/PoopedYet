/* ============================================================
 * 对比度自检（无障碍）
 *
 * 视觉稿里的色值都是手挑的，WCAG 对比度**不可能靠肉眼看出来**。
 * 这个脚本遍历所有带直接文本的元素，算出「有效前景色 / 有效背景色」，
 * 再按 WCAG 2.1 AA 判定：
 *   - 普通文本（< 24px，或 < 18.66px 且非粗体）  需 >= 4.5:1
 *   - 大号文本（>= 24px，或 >= 18.66px 且粗体）  需 >= 3.0:1
 *   - 图标等非文本（单独统计）                    需 >= 3.0:1
 *
 * 有效色的算法要点（这几条不做就会得出错误结论）：
 *   1. 背景要沿祖先链往上找第一个不透明背景，不能只看元素自身。
 *   2. 祖先链上的 opacity 会整体合成，必须累乘后把文字色往背景色上混。
 *   3. background-image 是渐变时，取渐变里第一个色标当背景近似值。
 *
 * 想主动降级对比度（比如日历里"非本月"的日期），给元素或其祖先加
 * class="a11y-dim-ok"，脚本会把它归到「已声明降级」而不是失败。
 *
 * 用法见 README-layout-check.md
 * ============================================================ */
(function () {
  var DIM_OK = 'a11y-dim-ok';

  function parseColor(s) {
    if (!s) return null;
    var m = s.match(/rgba?\(([^)]+)\)/);
    if (!m) return null;
    var p = m[1].split(/[,\s\/]+/).filter(function (x) { return x !== ''; }).map(parseFloat);
    if (p.length < 3) return null;
    return { r: p[0], g: p[1], b: p[2], a: p.length > 3 && !isNaN(p[3]) ? p[3] : 1 };
  }

  function lum(c) {
    function f(v) { v /= 255; return v <= 0.03928 ? v / 12.92 : Math.pow((v + 0.055) / 1.055, 2.4); }
    return 0.2126 * f(c.r) + 0.7152 * f(c.g) + 0.0722 * f(c.b);
  }

  function ratio(a, b) {
    var l1 = lum(a), l2 = lum(b);
    var hi = Math.max(l1, l2), lo = Math.min(l1, l2);
    return (hi + 0.05) / (lo + 0.05);
  }

  function blend(fg, bg, alpha) {
    return {
      r: fg.r * alpha + bg.r * (1 - alpha),
      g: fg.g * alpha + bg.g * (1 - alpha),
      b: fg.b * alpha + bg.b * (1 - alpha),
      a: 1
    };
  }

  // 沿祖先链找第一个不透明背景；渐变取第一个色标
  function bgOf(el) {
    var n = el;
    while (n && n.nodeType === 1) {
      var s = getComputedStyle(n);
      var c = parseColor(s.backgroundColor);
      if (c && c.a > 0.95) return c;
      if (s.backgroundImage && s.backgroundImage !== 'none') {
        var g = parseColor(s.backgroundImage);
        if (g) return g;
      }
      n = n.parentElement;
    }
    return { r: 255, g: 255, b: 255, a: 1 };
  }

  function opacityOf(el) {
    var o = 1, n = el;
    while (n && n.nodeType === 1) {
      var v = parseFloat(getComputedStyle(n).opacity);
      if (!isNaN(v)) o *= v;
      n = n.parentElement;
    }
    return o;
  }

  function visible(el) {
    var n = el;
    while (n && n.nodeType === 1) {
      var s = getComputedStyle(n);
      if (s.display === 'none' || s.visibility === 'hidden') return false;
      n = n.parentElement;
    }
    return el.getBoundingClientRect().width > 0;
  }

  function tag(el) {
    var cls = (typeof el.className === 'string' ? el.className : '').trim().split(/\s+/)[0] || '';
    return el.tagName.toLowerCase() + (cls ? '.' + cls : '');
  }

  function hasDimOk(el) {
    var n = el;
    while (n && n.nodeType === 1) {
      if (n.classList && n.classList.contains(DIM_OK)) return true;
      n = n.parentElement;
    }
    return false;
  }

  var fails = {}, dims = {}, icons = {};
  var checked = 0, iconChecked = 0;

  // ---- 文本 ----
  var all = [].slice.call(document.querySelectorAll('body *'));
  all.forEach(function (el) {
    if (el.closest('svg')) return;                       // svg 内部单独算
    var hasText = [].slice.call(el.childNodes).some(function (n) {
      return n.nodeType === 3 && n.textContent.trim();
    });
    if (!hasText) return;
    if (!visible(el)) return;

    var s = getComputedStyle(el);
    var fg0 = parseColor(s.color);
    if (!fg0) return;
    var bg = bgOf(el);
    var alpha = fg0.a * opacityOf(el);
    var fg = blend(fg0, bg, alpha);

    var size = parseFloat(s.fontSize);
    var weight = parseInt(s.fontWeight, 10) || 400;
    var large = size >= 24 || (size >= 18.66 && weight >= 700);
    var need = large ? 3.0 : 4.5;
    var got = ratio(fg, bg);
    checked++;

    if (got + 0.01 >= need) return;
    var key = tag(el) + ' | ' + s.color + ' on rgb(' +
      Math.round(bg.r) + ',' + Math.round(bg.g) + ',' + Math.round(bg.b) + ') | ' +
      size.toFixed(1) + 'px/' + weight + ' | ' + got.toFixed(2) + ':1 (需 ' + need + ')';
    var bucket = hasDimOk(el) ? dims : fails;
    if (!bucket[key]) bucket[key] = { n: 0, sample: (el.textContent || '').trim().slice(0, 24) };
    bucket[key].n++;
  });

  // ---- 图标（非文本对比，WCAG 1.4.11 要求 3:1）----
  [].slice.call(document.querySelectorAll('svg use, svg path, svg circle, svg line, svg rect')).forEach(function (el) {
    var svg = el.closest('svg');
    if (!svg || !visible(svg)) return;
    var s = getComputedStyle(svg);
    var fg0 = parseColor(s.color) || parseColor(s.stroke);
    if (!fg0) return;
    var bg = bgOf(svg);
    var fg = blend(fg0, bg, fg0.a * opacityOf(svg));
    var got = ratio(fg, bg);
    iconChecked++;
    if (got + 0.01 >= 3.0) return;
    var key = tag(svg.parentElement || svg) + ' | ' + s.color + ' | ' + got.toFixed(2) + ':1 (需 3.00)';
    /* 图标也必须认 a11y-dim-ok。
       踩过的坑：文本路径认了、图标路径忘了，于是降级格里被 .cell.dim .bdg{opacity:.4}
       淡化的头像被算成 4 处「不合格」，而同一个格子里的数字却正确地进了降级桶。
       同一个标记两套判定，等于自检自己骗自己。 */
    var bucket = hasDimOk(svg) ? dims : icons;
    if (!bucket[key]) bucket[key] = { n: 0, sample: '' };
    bucket[key].n++;
  });

  function dump(bucket, title) {
    var keys = Object.keys(bucket);
    if (!keys.length) return [title + ': 0'];
    keys.sort(function (a, b) { return bucket[b].n - bucket[a].n; });
    var lines = [title + ': ' + keys.length + ' 类 / ' +
      keys.reduce(function (a, k) { return a + bucket[k].n; }, 0) + ' 处'];
    keys.forEach(function (k) {
      lines.push('  x' + String(bucket[k].n).padStart(3) + '  ' + k +
        (bucket[k].sample ? '   「' + bucket[k].sample + '」' : ''));
    });
    return lines;
  }

  var out = [
    'A11Y_TEXT_CHECKED = ' + checked,
    'A11Y_ICON_CHECKED = ' + iconChecked,
    'A11Y_FAIL_COUNT = ' + Object.keys(fails).reduce(function (a, k) { return a + fails[k].n; }, 0),
    'A11Y_DIM_OK_COUNT = ' + Object.keys(dims).reduce(function (a, k) { return a + dims[k].n; }, 0),
    'A11Y_ICON_FAIL_COUNT = ' + Object.keys(icons).reduce(function (a, k) { return a + icons[k].n; }, 0)
  ]
    .concat([''])
    .concat(dump(fails, '【不合格】'))
    .concat([''])
    .concat(dump(dims, '【已声明降级 (a11y-dim-ok)】'))
    .concat([''])
    .concat(dump(icons, '【图标非文本不合格】'));

  document.body.innerHTML = '<pre id="A11Y">' + out.join('\n') + '</pre>';
})();

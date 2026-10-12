/* 布局自检脚本 —— 在没有肉眼可视图的情况下验证 UI 稿的布局正确性。
 *
 * 用法：把本文件内联注入到 ui-reference.html 的 body 结束标签之前，
 *       再用无头 Chrome 的 --dump-dom 回读页面里的 <pre id="DIAG"> 测量结果。
 *       用 #all 片段让所有分组同时显示，才能一次量到全部 19 屏。
 *
 * 能发现：日历格子内容溢出被裁切、记录列表被切掉、字体没加载、手机排布换行。
 * 完整命令行见同目录 README-layout-check.md。
 *
 * 判定标准：GRIDn 的 vOverflow / hOverflow 必须为 0，BROW_H_OVERFLOW 为 0，
 *           LISTn / PAGEn / SHEETn 的 CLIPPED 必须为 false，
 *           PHONESn 的 WRAPPED 必须为 false，FONT_SMILEY_LOADED 为 true。
 *
 * ⚠ 注意：本文件会被内联进 script 标签，注释里【不能】出现 script 的闭合标签字面量，
 *   否则 HTML 解析器会提前终止脚本（这个坑踩过一次）。
 */
window.addEventListener('load', function () {
  setTimeout(function () {
    var L = [];
    var P = function (k, v) { L.push(k + ' = ' + v); };

    P('VIEWPORT', window.innerWidth + ' x ' + window.innerHeight);
    P('SCROLL', document.documentElement.scrollWidth + ' x ' + document.documentElement.scrollHeight);
    P('H_OVERFLOW', document.documentElement.scrollWidth > window.innerWidth);

    var fontOK = 'n/a';
    try { fontOK = document.fonts.check('16px "Smiley Sans"'); } catch (e) { fontOK = 'err:' + e.message; }
    P('FONT_SMILEY_LOADED', fontOK);

    /* 图标雪碧图是否解析出内容（防止 <use> 全部落空） */
    var syms = document.querySelectorAll('symbol[id^="i-"]');
    var emptySym = 0;
    [].slice.call(syms).forEach(function (s) { if (!s.children.length) emptySym++; });
    P('SPRITE', 'symbols=' + syms.length + ' empty=' + emptySym);
    P('ICON_USES', document.querySelectorAll('.ic use').length);

    /* 每个分组是否有一行放不下、换行的情况；顺带暴露「分组其实没渲染」 */
    [].slice.call(document.querySelectorAll('.phones')).forEach(function (box, i) {
      var us = [].slice.call(box.querySelectorAll('.unit'));
      var tops = new Set(us.map(function (u) { return u.offsetTop; }));
      var laidOut = us.length > 0 && us[0].offsetHeight > 0;
      P('PHONES' + i, 'units=' + us.length + ' rows=' + tops.size +
         ' RENDERED=' + laidOut + ' WRAPPED=' + (laidOut && tops.size > 1));
    });

    P('SCREENS', document.querySelectorAll('.screen').length);
    var zeroScreens = 0;
    [].slice.call(document.querySelectorAll('.screen')).forEach(function (sc) {
      if (sc.clientHeight === 0) zeroScreens++;
    });
    P('SCREENS_NOT_LAID_OUT', zeroScreens);

    /* 机身内内容是否超过机身高度 */
    var scOver = 0;
    [].slice.call(document.querySelectorAll('.screen')).forEach(function (sc, i) {
      if (sc.scrollHeight > sc.clientHeight) {
        scOver++;
        P('SCREEN_OVERFLOW_' + i, (sc.scrollHeight - sc.clientHeight) + 'px');
      }
    });
    P('SCREEN_OVERFLOW_COUNT', scOver);

    /* 月/周日历格 */
    [].slice.call(document.querySelectorAll('.grid, .wgrid')).forEach(function (g, i) {
      var cells = g.querySelectorAll('.cell, .wcell');
      var worst = 0, worstIdx = -1, hworst = 0, hIdx = -1;
      [].slice.call(cells).forEach(function (c, j) {
        var o = c.scrollHeight - c.clientHeight;
        if (o > worst) { worst = o; worstIdx = j; }
        var hs = c.scrollWidth - c.clientWidth;
        if (hs > hworst) { hworst = hs; hIdx = j; }
      });
      P('GRID' + i, 'cells=' + cells.length + ' colW=' + (cells[0] ? cells[0].offsetWidth : -1) +
         ' vOverflow=' + worst + '@' + worstIdx + ' hOverflow=' + hworst + '@' + hIdx);
    });

    /* 徽标行横向溢出 */
    var bw = 0, bwIdx = -1;
    [].slice.call(document.querySelectorAll('.brow')).forEach(function (b, j) {
      var o = b.scrollWidth - b.clientWidth;
      if (o > bw) { bw = o; bwIdx = j; }
    });
    P('BROW_H_OVERFLOW', bw + '@' + bwIdx);

    /* 图标头像网格是否挤爆 */
    var agWorst = 0;
    [].slice.call(document.querySelectorAll('.avatar-grid')).forEach(function (g) {
      agWorst = Math.max(agWorst, g.scrollHeight - g.clientHeight);
    });
    P('AVATAR_GRID_V_OVERFLOW', agWorst);

    /* 图表柱高是否越界 */
    var barWorst = 0;
    [].slice.call(document.querySelectorAll('.chart .bar')).forEach(function (b) {
      if (b.offsetHeight > 118) barWorst = Math.max(barWorst, b.offsetHeight - 118);
    });
    P('CHART_BAR_OVERFLOW', barWorst);

    /* 列表页 / 设置页 / 弹层是否被裁切 */
    [].slice.call(document.querySelectorAll('.screen')).forEach(function (sc, i) {
      var scr = sc.querySelector('.scroller');
      var sp = sc.querySelector('.scrollpage');
      if (scr) P('LIST' + i, 'scrollH=' + scr.scrollHeight + ' clientH=' + scr.clientHeight +
                 ' CLIPPED=' + (scr.scrollHeight > scr.clientHeight));
      if (sp) {
        /* flex 子项默认会被压缩，不会溢出 —— 所以必须单独算「内容自然高度」才能发现挤压 */
        var kids = [].slice.call(sp.children);
        var need = kids.reduce(function (a, k) { return a + k.offsetHeight; }, 0) +
                   (kids.length > 1 ? (kids.length - 1) * 16 : 0);
        P('PAGE' + i, 'scrollH=' + sp.scrollHeight + ' clientH=' + sp.clientHeight +
           ' need=' + need + ' CLIPPED=' + (sp.scrollHeight > sp.clientHeight) +
           ' SQUEEZED=' + (need > sp.clientHeight + 1));
      }
      var sh = sc.querySelector('.sheet');
      if (sh) P('SHEET' + i, 'h=' + sh.offsetHeight + ' vsClient=' + sh.clientHeight +
                 ' screenH=' + sc.clientHeight + ' CLIPPED=' + (sh.scrollHeight > sh.clientHeight));
      var fab = sc.querySelector('.fab');
      if (fab) {
        var r = fab.getBoundingClientRect(), sr = sc.getBoundingClientRect();
        P('FAB' + i, 'inside=' + (r.right <= sr.right + 1 && r.bottom <= sr.bottom + 1 && r.left >= sr.left - 1));
      }
    });

    document.body.innerHTML = '<pre id="DIAG">' + L.join('\n') + '</pre>';
  }, 900);
});

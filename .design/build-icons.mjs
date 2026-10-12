/* 把 Lucide 图标内联成 SVG 雪碧图，写进 ui-reference.html。
 * Lucide 协议：ISC（可自由商用，保留版权声明即可）。
 *
 * 运行： node .design/build-icons.mjs
 * 依赖： .design/icons/svg/*.svg（取自 npm 的 lucide-static 包，只保留用到的 73 个，34 KB）
 *
 * 要加新图标：从 lucide-static 里拷对应的 svg 到 icons/svg/，再把名字加进下面的 ICONS。
 */
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const HERE = path.dirname(fileURLToPath(import.meta.url));
const SRC = path.join(HERE, 'icons', 'svg');
const TARGET = path.join(HERE, 'ui-reference.html');

/* 视觉稿里用到的全部图标。增删图标只需改这个列表再重跑。 */
export const ICONS = [
  // 品牌 / 导航
  'settings', 'settings-2', 'sun', 'moon', 'calendar-days', 'calendar-range',
  'chart-column', 'chevron-left', 'chevron-right', 'chevron-down', 'x', 'plus',
  'check', 'arrow-right', 'arrow-left', 'grip-vertical', 'ellipsis-vertical',
  // 屙屎人头像候选（动物 / 符号）
  'dog', 'cat', 'rabbit', 'bird', 'turtle', 'fish', 'snail', 'squirrel', 'bug',
  'ghost', 'star', 'heart', 'crown', 'rocket', 'leaf', 'flame', 'droplet', 'zap',
  'coffee', 'milk', 'pizza', 'utensils', 'party-popper',
  // 功能
  'pencil', 'trash-2', 'search', 'filter', 'sliders-horizontal', 'clock', 'timer',
  'circle-dot', 'notebook-pen', 'tag', 'tags', 'user', 'users', 'user-plus',
  'image', 'camera', 'palette', 'download', 'upload', 'smartphone', 'info',
  'triangle-alert', 'briefcase', 'graduation-cap', 'plane', 'home', 'map-pin',
  'sticky-note', 'play', 'square', 'wind', 'bed', 'bath',
];

const symbols = ICONS.map((name) => {
  const file = path.join(SRC, `${name}.svg`);
  if (!fs.existsSync(file)) throw new Error(`缺少图标: ${name} (${file})`);
  const raw = fs.readFileSync(file, 'utf8');
  // 只取 <svg> 内部内容；描边属性提到 symbol 上，由外层 .ic 的 currentColor 驱动
  const inner = raw
    .replace(/^[\s\S]*?<svg[^>]*>/, '')
    .replace(/<\/svg>[\s\S]*$/, '')
    .trim();
  return `  <symbol id="i-${name}" viewBox="0 0 24 24" fill="none" stroke="currentColor" ` +
         `stroke-width="2" stroke-linecap="round" stroke-linejoin="round">${inner}</symbol>`;
}).join('\n');

const sprite =
  `<svg xmlns="http://www.w3.org/2000/svg" style="display:none" aria-hidden="true">\n` +
  symbols + `\n</svg>`;

const MARK = /<!--SPRITE:START-->[\s\S]*?<!--SPRITE:END-->/;
let html = fs.readFileSync(TARGET, 'utf8');
if (!MARK.test(html)) {
  throw new Error('ui-reference.html 里没找到 <!--SPRITE:START--> / <!--SPRITE:END--> 标记');
}
const before = html;
/* 用函数式替换：字符串式替换会把 sprite 里的 $& / $1 之类当成特殊语法，是个潜在坑 */
html = html.replace(MARK, () => `<!--SPRITE:START-->\n${sprite}\n<!--SPRITE:END-->`);
fs.writeFileSync(TARGET, html, 'utf8');
console.log(`已内联 ${ICONS.length} 个 Lucide 图标（${html === before ? '内容无变化' : '已更新'}）` +
            ` -> ${path.relative(process.cwd(), TARGET)}`);

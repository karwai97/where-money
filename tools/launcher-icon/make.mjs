// The launcher icon: a receipt on C5 Graphite's dark ground, its total ruled in
// the accent. Drawn once here, on the 108dp adaptive-icon grid, and written out
// as Android vector drawables, the legacy Android PNGs, and the iOS icon set.
//
//   cd tools/launcher-icon && npm install && npm run make

import { Resvg } from '@resvg/resvg-js';
import { mkdirSync, readFileSync, writeFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const root = join(dirname(fileURLToPath(import.meta.url)), '..', '..');
const android = join(root, 'android', 'app', 'src', 'main', 'res');
const ios = join(root, 'ios', 'Runner', 'Assets.xcassets', 'AppIcon.appiconset');

const colour = {
  ground: '#15161A',
  paper: '#E5E6EB',
  rule: '#7E8290',
  total: '#5B47C4',
};

// Rounded rect as path data, because vector drawables have no <rect>.
const rounded = (x, y, w, h, r) =>
  `M${x + r} ${y} H${x + w - r} A${r} ${r} 0 0 1 ${x + w} ${y + r} V${y + h - r} A${r} ${r} 0 0 1 ${x + w - r} ${y + h} H${x + r} A${r} ${r} 0 0 1 ${x} ${y + h - r} V${y + r} A${r} ${r} 0 0 1 ${x + r} ${y} Z`;

// The slip: rounded top, serrated bottom. Everything sits inside the 66dp safe circle.
const slip =
  'M40 27 H68 A3 3 0 0 1 71 30 V78 L68.17 81 L65.33 78 L62.5 81 L59.67 78 L56.83 81 L54 78 L51.17 81 L48.33 78 L45.5 81 L42.67 78 L39.83 81 L37 78 V30 A3 3 0 0 1 40 27 Z';
const rules = [rounded(44, 36, 14, 3, 1.5), rounded(44, 44, 20, 3, 1.5), rounded(44, 52, 20, 3, 1.5)];
const total = rounded(44, 64, 20, 4, 2);

const shapes = [
  { d: slip, fill: colour.paper },
  ...rules.map((d) => ({ d, fill: colour.rule })),
  { d: total, fill: colour.total },
];

const svgPaths = shapes.map((s) => `<path d="${s.d}" fill="${s.fill}"/>`).join('\n    ');
const svgArt = (viewBox) => `<svg xmlns="http://www.w3.org/2000/svg" viewBox="${viewBox}">
    <rect width="108" height="108" fill="${colour.ground}"/>
    ${svgPaths}
  </svg>`;

const vectorPaths = shapes
  .map((s) => `    <path android:fillColor="${s.fill}" android:pathData="${s.d}"/>`)
  .join('\n');

const vector = (body) => `<?xml version="1.0" encoding="utf-8"?>
<vector xmlns:android="http://schemas.android.com/apk/res/android"
    android:width="108dp"
    android:height="108dp"
    android:viewportWidth="108"
    android:viewportHeight="108">
${body}
</vector>
`;

const write = (path, data) => {
  mkdirSync(dirname(path), { recursive: true });
  writeFileSync(path, data);
  console.log(path.slice(root.length + 1));
};

const png = (svg, width) => new Resvg(svg, { fitTo: { mode: 'width', value: width } }).render().asPng();

// The master, for anything that wants a vector of the whole icon.
write(join(root, 'tools', 'launcher-icon', 'ic_launcher.svg'), svgArt('0 0 108 108') + '\n');

// Android 8+: adaptive icon from vector layers. The monochrome layer is the
// slip with its rules knocked out, for themed icons on Android 13+.
write(join(android, 'drawable', 'ic_launcher_foreground.xml'), vector(vectorPaths));
write(
  join(android, 'drawable', 'ic_launcher_monochrome.xml'),
  vector(
    `    <path android:fillColor="#000000" android:fillType="evenOdd"\n        android:pathData="${[slip, ...rules, total].join(' ')}"/>`,
  ),
);
write(
  join(android, 'values', 'ic_launcher_background.xml'),
  `<?xml version="1.0" encoding="utf-8"?>\n<resources>\n    <color name="ic_launcher_background">${colour.ground}</color>\n</resources>\n`,
);
write(
  join(android, 'mipmap-anydpi-v26', 'ic_launcher.xml'),
  `<?xml version="1.0" encoding="utf-8"?>
<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
    <background android:drawable="@color/ic_launcher_background"/>
    <foreground android:drawable="@drawable/ic_launcher_foreground"/>
    <monochrome android:drawable="@drawable/ic_launcher_monochrome"/>
</adaptive-icon>
`,
);

// Android 7: no masks, so the 72dp mask region is drawn under a rounded square
// with the 2dp of transparent margin a 48dp legacy icon carries.
const legacy = `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 48 48">
  <clipPath id="tile"><rect x="2" y="2" width="44" height="44" rx="9.8"/></clipPath>
  <g clip-path="url(#tile)">
    <svg x="2" y="2" width="44" height="44" viewBox="18 18 72 72">
      <rect width="108" height="108" fill="${colour.ground}"/>
      ${svgPaths}
    </svg>
  </g>
</svg>`;
for (const [density, size] of Object.entries({ mdpi: 48, hdpi: 72, xhdpi: 96, xxhdpi: 144, xxxhdpi: 192 })) {
  write(join(android, `mipmap-${density}`, 'ic_launcher.png'), png(legacy, size));
}

// iOS masks its own corners, so this is the mask region edge to edge, at every
// size the asset catalogue lists.
const full = svgArt('18 18 72 72');
const catalogue = JSON.parse(readFileSync(join(ios, 'Contents.json'), 'utf8'));
for (const image of catalogue.images) {
  const points = parseFloat(image.size);
  const scale = parseInt(image.scale, 10);
  write(join(ios, image.filename), png(full, Math.round(points * scale)));
}

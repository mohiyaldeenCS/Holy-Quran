// «القرآن الكريم» — components. Built with esbuild into components/bundle.js (window.Quran).
// React comes from the page (window.React); every color, size and radius is a token from tokens.css.
const React = window.React;
const { useState } = React;
const cx = (...a) => a.filter(Boolean).join(' ');

const DIGITS = '٠١٢٣٤٥٦٧٨٩';
/** 255 → «٢٥٥». The interface writes every number in Arabic-Indic digits. */
export function arabicDigits(n) { return String(n).replace(/[0-9]/g, (d) => DIGITS[d]); }

/** Correct Arabic count of ayat: آية واحدة، آيتان، ٧ آيات، ٢٨٦ آية، ٢٠٦ آيات. */
export function ayahCount(n) {
  const m = n % 100;
  if (n === 1) return 'آية واحدة';
  if (n === 2) return 'آيتان';
  if (m >= 3 && m <= 10) return `${arabicDigits(n)} آيات`;
  return `${arabicDigits(n)} آية`;
}

/** Arabic count of times: مرة واحدة، مرتان، ٧ مرات، ١١ مرة. */
export function timesCount(n) {
  const m = n % 100;
  if (n === 1) return 'مرة واحدة';
  if (n === 2) return 'مرتان';
  if (m >= 3 && m <= 10) return `${arabicDigits(n)} مرات`;
  return `${arabicDigits(n)} مرة`;
}

// ---------------------------------------------------------------- icons
// 24 grid, 1.75 stroke, round ends; filled only for play/pause. Directional icons follow the reading direction.
const ICONS = {
  home: '<path d="M4 11.5 12 5l8 6.5V19a1 1 0 0 1-1 1h-4v-5H9v5H5a1 1 0 0 1-1-1z"/>',
  mushaf: '<path d="M12 6.5C10 5 7 4.6 4.5 5v13c2.5-.4 5.5 0 7.5 1.5 2-1.5 5-1.9 7.5-1.5V5C17 4.6 14 5 12 6.5zM12 6.5v13"/>',
  listen: '<path d="M4 14v-2a8 8 0 0 1 16 0v2"/><rect x="4" y="14" width="4" height="6" rx="1.5"/><rect x="16" y="14" width="4" height="6" rx="1.5"/>',
  study: '<path d="m12 4 8 4-8 4-8-4z"/><path d="m4 12 8 4 8-4"/><path d="m4 16 8 4 8-4"/>',
  search: '<circle cx="11" cy="11" r="6"/><path d="m20 20-4.2-4.2"/>',
  bookmark: '<path d="M7 4h10v16l-5-3.5L7 20z"/>',
  download: '<path d="M12 4v11"/><path d="m7.5 11 4.5 4.5 4.5-4.5"/><path d="M5 19.5h14"/>',
  night: '<path d="M19.5 14.5A8 8 0 0 1 9.5 4.5a8 8 0 1 0 10 10z"/>',
  settings: '<path d="M5 7h9M18 7h1M5 17h1M10 17h9"/><circle cx="16" cy="7" r="2"/><circle cx="8" cy="17" r="2"/>',
  repeat: '<path d="M5 11V9a3 3 0 0 1 3-3h10l-3-3M19 13v2a3 3 0 0 1-3 3H6l3 3"/>',
  index: '<path d="M8 6h12M8 12h12M8 18h12M4 6h.01M4 12h.01M4 18h.01"/>',
  khatma: '<circle cx="12" cy="12" r="8"/><circle cx="12" cy="12" r="3.5"/>',
  next: '<path d="m15 6-6 6 6 6"/>',
  previous: '<path d="m9 6 6 6-6 6"/>',
  more: '<circle cx="5" cy="12" r="1.2"/><circle cx="12" cy="12" r="1.2"/><circle cx="19" cy="12" r="1.2"/>',
  alert: '<path d="M12 4 21 19.5H3z"/><path d="M12 10v4M12 17h.01"/>',
  check: '<path d="m5 12.5 4.5 4.5L19 7.5"/>',
  close: '<path d="m7 7 10 10M17 7 7 17"/>',
  play: '<path d="M8 5.5v13l11-6.5z"/>',
  pause: '<rect x="6.5" y="5" width="3.8" height="14" rx="1"/><rect x="13.7" y="5" width="3.8" height="14" rx="1"/>',
  mic: '<rect x="9" y="3.5" width="6" height="11" rx="3"/><path d="M5.5 11.5a6.5 6.5 0 0 0 13 0M12 18v3"/>',
  eye: '<path d="M2.5 12S6 5.5 12 5.5 21.5 12 21.5 12 18 18.5 12 18.5 2.5 12 2.5 12z"/><circle cx="12" cy="12" r="3"/>',
  sort: '<path d="M7 5v14M4 8l3-3 3 3M17 19V5M14 16l3 3 3-3"/>',
  minus: '<path d="M6 12h12"/>',
  plus: '<path d="M12 6v12M6 12h12"/>',
  context: '<path d="M5 6h14M5 10h14"/><rect x="4" y="13.5" width="16" height="5" rx="1.5"/>',
};
const FILLED = { play: 1, pause: 1 };
export const iconNames = Object.keys(ICONS);

/** One icon from the set. Decorative unless `label` is given. */
export function Icon({ name, size = 24, label, className, style }) {
  const filled = FILLED[name];
  return React.createElement('svg', {
    className: cx('qk-icon', className), width: size, height: size, viewBox: '0 0 24 24',
    fill: filled ? 'currentColor' : 'none', stroke: filled ? 'none' : 'currentColor',
    strokeWidth: 1.75, strokeLinecap: 'round', strokeLinejoin: 'round', style,
    role: label ? 'img' : undefined, 'aria-label': label, 'aria-hidden': label ? undefined : true,
    dangerouslySetInnerHTML: { __html: ICONS[name] || '' },
  });
}

// ---------------------------------------------------------------- brand mark
const BOOK = 'M58 52C52 47.5 44 47 38.5 49.5V72C44 69.8 52 70.3 58 74.5zM62 52C68 47.5 76 47 81.5 49.5V72C76 69.8 68 70.3 62 74.5z';
const MARK_VARIANTS = {
  paper: { star: 'var(--ornament)', book: 'var(--brand-ink)', fill: 0.14 },
  emerald: { star: 'var(--gold-400)', book: 'var(--paper-100)', fill: 0.14 },
  dark: { star: 'var(--gold-400)', book: '#E8E2D0', fill: 0.12 },
  mono: { star: 'currentColor', book: 'currentColor', fill: 0 },
};
function markStroke(size) { return size >= 96 ? 2.2 : size >= 64 ? 3 : size >= 48 ? 3.6 : size >= 32 ? 5 : 6.5; }

/** The quarter-star with the open book and the upper dot. The dot is dropped under 32px, the stroke thickens as it shrinks. */
export function Mark({ size = 48, variant = 'paper', label = 'القرآن الكريم', decorative = false }) {
  const v = MARK_VARIANTS[variant] || MARK_VARIANTS.paper;
  const sw = markStroke(size);
  return (
    <svg width={size} height={size} viewBox="0 0 120 120" role={decorative ? undefined : 'img'} aria-label={decorative ? undefined : label} aria-hidden={decorative || undefined}>
      <g fill={v.fill ? v.star : 'none'} fillOpacity={v.fill || undefined} stroke={v.star} strokeWidth={sw} strokeLinejoin="round">
        <rect x="32" y="32" width="56" height="56" />
        <rect x="32" y="32" width="56" height="56" transform="rotate(45 60 60)" />
      </g>
      <path fill={v.book} d={BOOK} />
      {size >= 32 ? <circle cx="60" cy="39.5" r={size >= 64 ? 2.6 : 3.2} fill={v.star} /> : null}
    </svg>
  );
}

/** Mark + name. `onEmerald` for the splash screen and share cards. */
export function Lockup({ size = 48, onEmerald = false, stacked = false }) {
  return (
    <div className={cx('qk-lockup', stacked && 'qk-lockup-stacked', onEmerald && 'qk-on-emerald')}>
      <Mark size={stacked ? size * 1.4 : size} variant={onEmerald ? 'emerald' : 'paper'} decorative />
      <span className="qk-lockup-name" style={{ fontSize: Math.round(size * 0.5) }}>القرآن الكريم</span>
    </div>
  );
}

/** Quarter-star outline alone (surah headers, index numbers, margin markers). */
export function StarOutline({ size = 28, stroke = 5, className }) {
  return (
    <svg className={cx('qk-star', className)} width={size} height={size} viewBox="0 0 120 120" fill="none" aria-hidden="true">
      <g stroke="currentColor" strokeWidth={stroke} strokeLinejoin="round">
        <rect x="32" y="32" width="56" height="56" />
        <rect x="32" y="32" width="56" height="56" transform="rotate(45 60 60)" />
      </g>
    </svg>
  );
}

// ---------------------------------------------------------------- actions
/** Buttons: 52 tall, radius 16, 17px semibold. One primary per view. */
export function Button({ variant = 'primary', icon, children, className, ...rest }) {
  return (
    <button type="button" className={cx('qk-btn', `qk-btn-${variant}`, className)} {...rest}>
      {icon ? <Icon name={icon} size={22} /> : null}
      {children}
    </button>
  );
}

/** Icon-only button, 48px round. `label` is required: it is the accessible name. */
export function IconButton({ icon, label, tone = 'plain', size = 48, iconSize = 24, className, ...rest }) {
  return (
    <button type="button" aria-label={label} className={cx('qk-iconbtn', `qk-iconbtn-${tone}`, className)} style={{ width: size, height: size }} {...rest}>
      <Icon name={icon} size={iconSize} />
    </button>
  );
}

// ---------------------------------------------------------------- selection controls
/** The interface level: بسيط / متوسط / دراسة. Switching never deletes user data. */
export function LevelSwitch({ value, defaultValue = 0, onChange, options = ['بسيط', 'متوسط', 'دراسة'], label = 'مستوى الواجهة' }) {
  const [inner, setInner] = useState(defaultValue);
  const cur = value ?? inner;
  return (
    <div className="qk-seg" role="radiogroup" aria-label={label}>
      {options.map((o, i) => (
        <button key={o} type="button" role="radio" aria-checked={cur === i} className={cx('qk-seg-item', cur === i && 'is-on')}
          onClick={() => { setInner(i); onChange && onChange(i); }}>{o}</button>
      ))}
    </div>
  );
}

const TAG_SHAPES = { circle: 'qk-tag-dot-circle', square: 'qk-tag-dot-square', diamond: 'qk-tag-dot-diamond', ring: 'qk-tag-dot-ring' };
/** Bookmark / collection category. Shape + color + word: never color alone. */
export function Tag({ shape = 'circle', color = 'var(--primary)', selected = false, children, onClick }) {
  return (
    <button type="button" className={cx('qk-tag', selected && 'is-on')} aria-pressed={selected} onClick={onClick}>
      <span className={cx('qk-tag-dot', TAG_SHAPES[shape])} style={{ '--tag-color': color }} />
      {children}
    </button>
  );
}

/** Settings switch, 56×32. In RTL the knob sits on the left when on. */
export function Switch({ checked, defaultChecked = false, onChange, label }) {
  const [inner, setInner] = useState(defaultChecked);
  const on = checked ?? inner;
  return (
    <label className="qk-switch-row">
      <span>{label}</span>
      <button type="button" role="switch" aria-checked={on} className={cx('qk-switch', on && 'is-on')}
        onClick={() => { setInner(!on); onChange && onChange(!on); }}>
        <span className="qk-switch-knob" />
      </button>
    </label>
  );
}

// ---------------------------------------------------------------- mushaf
/** Ayah-end marker: thin gold ring, number inside. `playing` fills it while the ayah is recited. */
export function AyahMarker({ number, playing = false, size = 26 }) {
  const n = arabicDigits(number);
  return (
    <span className={cx('qk-ayah-no', playing && 'is-playing')} style={{ width: size, height: size, fontSize: n.length > 2 ? size * 0.38 : size * 0.46 }} aria-label={`الآية ${n}`}>{n}</span>
  );
}

/** Quranic text. Pass the text exactly as it comes from the approved source; never compose it. */
export function QuranText({ children, size = 'page', align = 'justify', as = 'div' }) {
  return React.createElement(as, { className: cx('qk-quran', `qk-quran-${size}`, align === 'center' && 'qk-quran-center'), lang: 'ar' }, children);
}

/** Surah header: double gold frame, quarter-stars on both sides, name in Reem Kufi. */
export function SurahHeader({ name, size = 'md', info }) {
  return (
    <div className={cx('qk-surah-header', `qk-surah-header-${size}`)}>
      <div className="qk-surah-header-inner">
        <StarOutline size={size === 'lg' ? 32 : 28} />
        <span className="qk-surah-header-name">سورة {name}</span>
        <StarOutline size={size === 'lg' ? 32 : 28} />
      </div>
      {info ? <div className="qk-surah-header-info">{info}</div> : null}
    </div>
  );
}

/** One ayah as a card: marker, actions (play from here, bookmark, study), then the text. */
export function AyahRow({ number, children, onPlay, onBookmark, onStudy }) {
  return (
    <div className="qk-ayah-row">
      <div className="qk-ayah-row-top">
        <AyahMarker number={number} size={36} />
        <div className="qk-ayah-row-actions">
          <IconButton icon="play" label="تشغيل من هنا" onClick={onPlay} />
          <IconButton icon="bookmark" label="علامة مرجعية" onClick={onBookmark} />
          <IconButton icon="study" label="مركز الدراسة" onClick={onStudy} />
        </div>
      </div>
      <QuranText size="ayah" align="start">{children}</QuranText>
    </div>
  );
}

/** Surah index row: number inside a quarter-star, name, Makki/Madani and ayah count, start page. */
export function SurahListItem({ number, name, revelation, ayat, page, lastRead = false, onClick }) {
  return (
    <button type="button" className="qk-surah-item" onClick={onClick}>
      <span className="qk-surah-item-no"><StarOutline size={44} stroke={4} /><span>{arabicDigits(number)}</span></span>
      <span className="qk-surah-item-main">
        <span className="qk-surah-item-name">{name}{lastRead ? <span className="qk-badge"><span className="qk-badge-dot" />آخر قراءة</span> : null}</span>
        <span className="qk-surah-item-meta">{revelation} · {ayahCount(ayat)}</span>
      </span>
      <span className="qk-surah-item-page"><span>صفحة</span><b>{arabicDigits(page)}</b></span>
    </button>
  );
}

// ---------------------------------------------------------------- audio & progress
/** Progress track; fills from the inline start (the right in Arabic). */
export function ProgressBar({ value = 0, tone = 'primary', height = 6, label }) {
  return (
    <div className={cx('qk-progress', `qk-progress-${tone}`)} style={{ height }} role="progressbar" aria-valuemin={0} aria-valuemax={100} aria-valuenow={Math.round(value)} aria-label={label}>
      <div className="qk-progress-fill" style={{ width: `${value}%` }} />
    </div>
  );
}

/** The emerald player card: title, reciter, speed, progress and five controls. */
export function MiniPlayer({ title, reciter, progress = 0, speed = '١٫٠×', playing = true, repeat = 0 }) {
  return (
    <div className="qk-player">
      <div className="qk-player-head">
        <div><div className="qk-player-title">{title}</div><div className="qk-player-sub">{reciter}</div></div>
        <span className="qk-player-speed">{speed}</span>
      </div>
      <ProgressBar value={progress} tone="player" label="موضع التلاوة" />
      <div className="qk-player-controls">
        <button type="button" className="qk-player-btn" aria-label={repeat ? `تكرار ${arabicDigits(repeat)} مرات` : 'تكرار'}><Icon name="repeat" size={26} />{repeat ? <span className="qk-player-count">{arabicDigits(repeat)}</span> : null}</button>
        <button type="button" className="qk-player-btn" aria-label="الآية السابقة"><Icon name="previous" size={26} /></button>
        <button type="button" className="qk-player-main" aria-label={playing ? 'إيقاف مؤقت' : 'تشغيل'}><Icon name={playing ? 'pause' : 'play'} size={28} /></button>
        <button type="button" className="qk-player-btn" aria-label="الآية التالية"><Icon name="next" size={26} /></button>
        <button type="button" className="qk-player-btn" aria-label="مؤقت النوم"><Icon name="night" size={26} /></button>
      </div>
    </div>
  );
}

/** «أكمل القراءة»: the emerald card on the home screen; the upper dot of the mark becomes this card. */
export function ContinueCard({ label = 'أكمل القراءة', title, meta, progress = 0, action = 'تابع القراءة', onClick }) {
  return (
    <div className="qk-continue">
      <svg className="qk-continue-stars" width="200" height="200" viewBox="0 0 120 120" fill="none" aria-hidden="true"><g stroke="currentColor" strokeWidth="0.8"><rect x="32" y="32" width="56" height="56" /><rect x="32" y="32" width="56" height="56" transform="rotate(45 60 60)" /></g></svg>
      <span className="qk-continue-label">{label}</span>
      <span className="qk-continue-title">{title}</span>
      <span className="qk-continue-meta">{meta}</span>
      <ProgressBar value={progress} tone="player" label="الموضع في المصحف" />
      <button type="button" className="qk-continue-btn" onClick={onClick}>{action}</button>
    </div>
  );
}

/** A row of the downloads manager: downloaded / downloading / available. Status always has words. */
export function ResourceRow({ title, status = 'available', size, progress = 0, onAction }) {
  return (
    <div className="qk-resource">
      <div className="qk-resource-main">
        <div className="qk-resource-title">{title}</div>
        {status === 'downloading' ? <ProgressBar value={progress} label={`تنزيل ${title}`} /> : (
          <div className={cx('qk-resource-meta', status === 'downloaded' && 'is-done')}>
            {status === 'downloaded' ? <><Icon name="check" size={16} />تم التنزيل · {size}</> : <>متاحة · {size}</>}
          </div>
        )}
      </div>
      {status === 'downloaded' ? <button type="button" className="qk-btn-small qk-btn-small-outline" onClick={onAction}>حذف</button>
        : status === 'downloading' ? <span className="qk-resource-pct">{arabicDigits(progress)}٪</span>
        : <button type="button" className="qk-btn-small" onClick={onAction}>تنزيل</button>}
    </div>
  );
}

// ---------------------------------------------------------------- tajweed
export const TAJWEED_RULES = {
  ghunna: { name: 'غنّة', desc: 'صوت أنفي يصاحب النون والميم المشدّدتين.', line: 'dotted', pos: 'under' },
  idgham: { name: 'إدغام', desc: 'إدخال حرف ساكن في حرف متحرك بعده.', line: 'solid', pos: 'under' },
  ikhfa: { name: 'إخفاء', desc: 'نطق بين الإظهار والإدغام مع غنّة.', line: 'dashed', pos: 'under' },
  iqlab: { name: 'إقلاب', desc: 'قلب النون الساكنة أو التنوين ميمًا قبل الباء.', line: 'double', pos: 'under' },
  qalqala: { name: 'قلقلة', desc: 'اضطراب الصوت عند حروف «قطب جد» إذا سكنت.', line: 'wavy', pos: 'under' },
  'madd-tabii': { name: 'مدّ طبيعي', desc: 'مدّ بمقدار حركتين بلا سبب زائد.', line: 'thin', pos: 'over' },
  'madd-wajib': { name: 'مدّ متصل ومنفصل', desc: 'زيادة المدّ بسبب همز بعد حرف المدّ.', line: 'thick', pos: 'over' },
  'madd-lazim': { name: 'مدّ لازم', desc: 'ست حركات لسكون أصلي بعد حرف المدّ.', line: 'twin', pos: 'over' },
};
const LINES = {
  dotted: 'M3 7h.01M11 7h.01M19 7h.01M27 7h.01M35 7h.01M43 7h.01',
  solid: 'M2 7h40', dashed: 'M2 7h10M17 7h10M32 7h10', double: 'M2 3.5h40M2 10.5h40',
  wavy: 'M2 7c3-6 6-6 9 0s6 6 9 0 6-6 9 0 6 6 9 0', thin: 'M2 3h40', thick: 'M2 4h40', twin: 'M2 2.5h40M2 7.5h40',
};
const LINE_W = { dotted: 4, solid: 3, dashed: 3, double: 2.5, wavy: 2.5, thin: 1.5, thick: 5, twin: 2.5 };

/** The line mark that stands for a rule without color. */
export function TajweedLine({ rule, width = 44 }) {
  const r = TAJWEED_RULES[rule];
  return (
    <svg width={width} height={14} viewBox="0 0 44 14" fill="none" aria-hidden="true" style={{ color: `var(--tj-${rule})` }}>
      <path d={LINES[r.line]} stroke="currentColor" strokeWidth={LINE_W[r.line]} strokeLinecap="round" />
    </svg>
  );
}

/** Legend entry: line mark + color swatch + name (+ description). */
export function TajweedKey({ rule, compact = false }) {
  const r = TAJWEED_RULES[rule];
  if (compact) return <span className="qk-tj-chip" style={{ color: `var(--tj-${rule})` }}><TajweedLine rule={rule} width={30} />{r.name}</span>;
  return (
    <div className="qk-tj-key">
      <TajweedLine rule={rule} />
      <span className="qk-tj-swatch" style={{ background: `var(--tj-${rule})` }} />
      <div><div className="qk-tj-name" style={{ color: `var(--tj-${rule})` }}>{r.name}</div><div className="qk-tj-desc">{r.desc}</div></div>
    </div>
  );
}

/** Wraps the letters a rule applies to inside Quranic text (color + its line mark). */
export function Tajweed({ rule, children }) {
  return <span className={cx('qk-tj', `qk-tj-${rule}`)} title={TAJWEED_RULES[rule].name}>{children}</span>;
}

// ---------------------------------------------------------------- navigation
const TABS = [['home', 'الرئيسية'], ['mushaf', 'المصحف'], ['listen', 'الاستماع'], ['study', 'الدراسة'], ['more', 'المزيد']];
/** Bottom navigation, five tabs. The active one gets a soft emerald pill. */
export function TabBar({ active = 'home', items = TABS, onChange }) {
  return (
    <nav className="qk-tabbar" aria-label="التنقل الرئيسي">
      {items.map(([key, label]) => (
        <button key={key} type="button" className={cx('qk-tab', key === active && 'is-on')} aria-current={key === active ? 'page' : undefined} onClick={() => onChange && onChange(key)}>
          <span className="qk-tab-pill"><Icon name={key} size={24} /></span>
          <span className="qk-tab-label">{label}</span>
        </button>
      ))}
    </nav>
  );
}

// ---------------------------------------------------------------- study
/** Word study sheet: tabs, the word, and label/value rows. Data shown must come from a named source. */
export function WordSheet({ word, position, tabs = ['النص', 'التفسير', 'الإعراب', 'الصرف', 'التجويد'], activeTab = 2, rows = [], note }) {
  return (
    <div className="qk-sheet">
      <div className="qk-sheet-handle" />
      <div className="qk-sheet-tabs" role="tablist">
        {tabs.map((t, i) => <span key={t} role="tab" aria-selected={i === activeTab} className={cx('qk-sheet-tab', i === activeTab && 'is-on')}>{t}</span>)}
      </div>
      <div className="qk-sheet-word"><QuranText size="focus" as="span">{word}</QuranText><span className="qk-sheet-pos">{position}</span></div>
      <div className="qk-sheet-rows">
        {rows.map(([k, v]) => <div key={k} className="qk-sheet-row"><span>{k}</span><b>{v}</b></div>)}
      </div>
      {note ? <div className="qk-sheet-note">{note}</div> : null}
    </div>
  );
}

// ---------------------------------------------------------------- search
/** Search field: icon, text, and a microphone for «اقرأ جزءًا من الآية». 56 tall; the ring turns emerald while it has focus. */
export function SearchField({ value, defaultValue = '', onChange, onVoice, placeholder = 'ابحث في القرآن', label = 'ابحث في القرآن' }) {
  const [inner, setInner] = useState(defaultValue);
  const cur = value ?? inner;
  return (
    <div className="qk-search" role="search">
      <Icon name="search" size={22} />
      <input type="search" className="qk-search-input" value={cur} placeholder={placeholder} aria-label={label} enterKeyHint="search"
        onChange={(e) => { setInner(e.target.value); onChange && onChange(e.target.value); }} />
      <button type="button" className="qk-search-voice" aria-label="ابحث بالصوت: اقرأ جزءًا من الآية" onClick={onVoice}><Icon name="mic" size={22} /></button>
    </div>
  );
}

/** Search modes: كلمة، الجذر، بلا تشكيل… One is always selected, and it carries a check mark besides the fill. */
export function ModeChips({ options = ['كلمة', 'الجذر', 'بلا تشكيل', 'المشتقات', 'في التفاسير', 'الموضوعات'], value, defaultValue = 0, onChange, label = 'نوع البحث' }) {
  const [inner, setInner] = useState(defaultValue);
  const cur = value ?? inner;
  return (
    <div className="qk-chips" role="radiogroup" aria-label={label}>
      {options.map((o, i) => (
        <button key={o} type="button" role="radio" aria-checked={cur === i} className={cx('qk-chip', cur === i && 'is-on')}
          onClick={() => { setInner(i); onChange && onChange(i); }}>
          {cur === i ? <Icon name="check" size={16} /> : null}{o}
        </button>
      ))}
    </div>
  );
}

/** What was searched and how many results, with the sort order at the end of the row. */
export function SearchSummary({ title, count, sort = 'ترتيب المصحف', onSort }) {
  return (
    <div className="qk-summary">
      <div><div className="qk-summary-title">{title}</div><div className="qk-summary-count">{count}</div></div>
      <button type="button" className="qk-summary-sort" onClick={onSort}><Icon name="sort" size={18} />{sort}</button>
    </div>
  );
}

/** The matched word inside a result. Underline + tint, so it is not marked by color alone. */
export function Match({ children }) {
  return <mark className="qk-hl-search">{children}</mark>;
}

/** One search result: where it is, the ayah with its matches, and two actions (context, open in the mushaf).
 *  `clamp` cuts a long ayah at ~3 lines with a fade and a link that shows it whole. */
export function SearchResult({ reference, children, clamp = false, onContext, onOpen }) {
  const [open, setOpen] = useState(false);
  const cut = clamp && !open;
  return (
    <div className="qk-result">
      <div className="qk-result-top">
        <span className="qk-result-ref">{reference}</span>
        <span className="qk-result-actions">
          <IconButton icon="context" label="سياق الآية" iconSize={22} onClick={onContext} />
          <IconButton icon="mushaf" label="افتح في المصحف" iconSize={22} onClick={onOpen} />
        </span>
      </div>
      <div className={cx('qk-result-body', cut && 'is-clamped')}>
        <QuranText size="compact" align="start">{children}</QuranText>
        {cut ? <span className="qk-result-fade" aria-hidden="true" /> : null}
      </div>
      {cut ? <button type="button" className="qk-result-more" onClick={() => setOpen(true)}>الآية طويلة · اعرضها كاملة</button> : null}
    </div>
  );
}

/** Context sheet: the ayah with the ones before and after. `children` is the Quranic text (the current ayah wrapped in .qk-hl-select). */
export function ContextSheet({ title = 'سياق الآية', subtitle = 'ما قبلها وما بعدها', reference, options = ['آية', '٣ آيات', '٥ آيات', 'السورة'], value, defaultValue = 0, onChange, children, onOpen, onPlay }) {
  return (
    <div className="qk-sheet qk-ctx">
      <div className="qk-sheet-handle" />
      <div className="qk-ctx-head">
        <span className="qk-ctx-title">{title}<small>{subtitle}</small></span>
        <span className="qk-ctx-ref">{reference}</span>
      </div>
      <LevelSwitch options={options} value={value} defaultValue={defaultValue} onChange={onChange} label="مقدار السياق" />
      <QuranText size="compact" align="justify">{children}</QuranText>
      <div className="qk-ctx-actions">
        <Button onClick={onOpen} className="qk-ctx-open">افتح في المصحف</Button>
        <button type="button" className="qk-ctx-play" aria-label="تشغيل من هذه الآية" onClick={onPlay}><Icon name="play" size={22} /></button>
      </div>
    </div>
  );
}

// ---------------------------------------------------------------- memorization
/** Repetition counter: done = filled, current = gold ring, upcoming = empty ring. The count is also spoken. */
export function RepeatDots({ total = 7, done = 0, label }) {
  const name = label || `التكرارات المنجزة: ${arabicDigits(done)} من ${arabicDigits(total)}`;
  return (
    <span className="qk-dots" role="img" aria-label={name}>
      {Array.from({ length: total }, (_, i) => <span key={i} className={cx('qk-dot', i < done ? 'is-done' : i === done ? 'is-now' : 'is-next')} />)}
    </span>
  );
}

/** Top card of a memorization session: step, ayah and repetition, and the dots. */
export function SessionStatus({ step, ayah, repetition, total = 7, steps }) {
  return (
    <div className="qk-status">
      <div>
        <div className="qk-status-step">الخطوة {arabicDigits(step)} من {arabicDigits(steps)}</div>
        <div className="qk-status-title">{ayah} · التكرار {arabicDigits(repetition)} من {arabicDigits(total)}</div>
      </div>
      <RepeatDots total={total} done={repetition - 1} />
    </div>
  );
}

const LETTER = /[ء-يٱ]/;
/** Memorization text with its ink withheld. The text is still there word for word (selectable, same length);
 *  a screen reader hears only «الآية مخفية». A waqf mark stays inside the span of the word before it. */
export function ConcealedText({ children, revealed = false, label = 'الآية مخفية' }) {
  const text = String(children);
  if (revealed) return <span>{text}</span>;
  const groups = [];
  text.split(' ').forEach((t) => {
    if (groups.length && !LETTER.test(t)) groups[groups.length - 1] += ' ' + t; else groups.push(t);
  });
  return (
    <span role="img" aria-label={label}>
      {groups.map((g, i) => <React.Fragment key={i}>{i ? ' ' : ''}<span className="qk-conceal" aria-hidden="true">{g}</span></React.Fragment>)}
    </span>
  );
}

/** The floating emerald bar of a session: pause/resume, what is happening, and skip to the next step. */
export function SessionBar({ title, detail, playing = true, onToggle, onNext }) {
  return (
    <div className="qk-sbar">
      <button type="button" className="qk-sbar-main" aria-label={playing ? 'إيقاف مؤقت' : 'متابعة'} onClick={onToggle}><Icon name={playing ? 'pause' : 'play'} size={26} /></button>
      <div className="qk-sbar-text"><div className="qk-sbar-title">{title}</div><div className="qk-sbar-detail">{detail}</div></div>
      <button type="button" className="qk-sbar-next" aria-label="الخطوة التالية" onClick={onNext}><Icon name="next" size={24} /></button>
    </div>
  );
}

/** Number setting with minus and plus (48px targets): repetitions, merge repetitions, silence. */
export function Stepper({ label, value, defaultValue = 1, min = 1, max = 99, unit, onChange }) {
  const [inner, setInner] = useState(defaultValue);
  const cur = value ?? inner;
  const set = (n) => { const v = Math.min(max, Math.max(min, n)); setInner(v); onChange && onChange(v); };
  return (
    <div className="qk-stepper">
      <span>{label}</span>
      <span className="qk-stepper-ctl">
        <button type="button" className="qk-stepper-btn" aria-label={`إنقاص ${label}`} disabled={cur <= min} onClick={() => set(cur - 1)}><Icon name="minus" size={18} /></button>
        <output className="qk-stepper-val" aria-live="polite">{arabicDigits(cur)}{unit ? ` ${unit}` : ''}</output>
        <button type="button" className="qk-stepper-btn" aria-label={`زيادة ${label}`} disabled={cur >= max} onClick={() => set(cur + 1)}><Icon name="plus" size={18} /></button>
      </span>
    </div>
  );
}

/** A row of the session sequence. State is shown by shape (check / gold ring / empty ring) and bold, never by color alone. */
export function PlanStep({ state = 'next', title, repeats, merge = false }) {
  return (
    <div className={cx('qk-step', `is-${state}`)} aria-current={state === 'current' ? 'step' : undefined}>
      <span className="qk-step-mark">{state === 'done' ? <Icon name="check" size={16} style={{ strokeWidth: 3 }} /> : null}</span>
      <span className="qk-step-title">{title}{merge ? <span className="qk-step-merge">دمج</span> : null}</span>
      <span className="qk-step-reps">{repeats}</span>
      {state === 'done' ? <span className="qk-sr">تمّت</span> : null}
    </div>
  );
}

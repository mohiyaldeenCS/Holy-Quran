هوية هادئة وموقّرة تخدم النص ولا تنافسه: مدخل بسيط للقارئ، وعمق متدرّج للدارس. نجمة الربع المأخوذة من زخرفة المصاحف تحتضن كتابًا مفتوحًا. الزخرفة في الحواف والنص في المركز، وكل ما عدا ذلك يتراجع ليبقى المصحف هو الأصل.

## المبادئ

- **وقار.** لا ألوان صاخبة ولا حركة تشتّت. تتراجع الواجهة كلما اقتربت من النص القرآني.
- **وضوح.** تباين عالٍ، وأحجام تقبل التكبير، ولا يُترك معنى للون وحده.
- **عمق متدرّج.** واجهة بسيطة افتراضيًا، وأدوات الدراسة تظهر عند الطلب (`LevelSwitch`).

## سلامة النص القرآني في التصميم

هذه القواعد مقدَّمة على كل ما بعدها.

- اعرض النص القرآني كما ورد من المصدر المعتمد حرفًا بحرف، داخل `QuranText` أو بأحد أنماط `quran-page` و`quran-ayah` و`quran-focus`. لا تكتبه يدويًا، ولا تركّبه من أجزاء، ولا تعدّل ترميزه.
- النص وخطه زوج واحد. خط أميري قرآن مصمَّم لنص مشروع تنزيل العثماني. أما نص مجمع الملك فهد فيستخدم ترميزًا مختلفًا (التنوين المتتابع مثلًا)، وأميري قرآن لا يرسم بعضه، فيحتاج خط المجمع نفسه. ووضع صفحات مصحف المدينة (٦٠٤ صفحات) يُعرض بخطوط صفحات المجمع.
- لا تطبّق تسوية يونيكود (NFC أو NFKC) على النص القرآني ولا تنظّفه آليًا. التسوية تعيد ترتيب الشدة والحركات، فيبقى الشكل كما هو وتتغير البصمة (Hash) التي يُتحقق بها من سلامة النص.
- نص تنزيل الخام يضع البسملة في أول الآية الأولى من كل سورة. اعرضها سطرًا مستقلًا بعد رأس السورة ولا تكررها داخل الآية. في نسخة XML من تنزيل تأتي البسملة حقلًا مستقلًا.
- لا تُلوِّن النص بغير ألوان التجويد `tj-*`، ولا تضعه فوق صورة أو زخرفة، ولا تضف تباعدًا بين الحروف ولا عريضًا أو مائلًا.
- في المشاركة والنسخ تبقى الآية كاملة ومعها مرجعها. صيغة النسخ: ﴿نص الآية﴾ [السورة: رقم الآية].
- كل معلومة لغوية أو تفسيرية تُعرض ومعها اسم مصدرها. في التصاميم تُكتب الحقول التي لا نملك بياناتها بين معقوفين: [اسم القارئ]، [اسم التفسير]، [الحجم].

## النبرة والكتابة

- الواجهة عربية بالكامل، من اليمين إلى اليسار، بلا ترجمات للقرآن.
- جمل قصيرة، والفعل أولًا: «ابدأ التلاوة»، «تابع القراءة»، «أضف إلى مجموعة»، «أعِد التوزيع». التحية هادئة: «السلام عليكم»، ثم «أكمل من حيث توقفت».
- الأرقام عربية مشرقية في كل مكان (`arabicDigits`): «الآية ٢٥٥ · صفحة ٤٢ · الجزء ٣». الفاصل بين البيانات نقطة وسطى « · ». الكسر العشري «٫» والنسبة «٪».
- عُدّ الآيات بالعربية الصحيحة (`ayahCount`): آية واحدة، آيتان، ٧ آيات، ٢٨٦ آية، ٢٠٦ آيات.
- لا رموز تعبيرية ولا علامات تعجب. الحالات تُقال بكلمات: «تم التنزيل»، «متأخر ٢١ صفحة عن الخطة»، «تعذّر الاتصال».
- الإحصاءات هادئة: تقدّم وأرقام، بلا مديح ولا لوم.

## الألوان

ثلاث عائلات: **زمرد** (`emerald-*`) للفعل والهوية، و**ذهب** (`gold-*`) للزخرفة والتمييز، و**ورق وحبر** (`paper-*` و`ink-*`) للأرضية والنص. نسبة الاستخدام في أي شاشة تقريبًا: ورق ٦٠٪، حبر ٢٢٪، زمرد ١٣٪، ذهب ٥٪. يبقى الورق والحبر هما الغالبين، فلا يزاحم لونٌ آية.

- استخدم الرموز الدلالية في الواجهات، لا الدرجات الخام: `ground` و`surface` و`surface-sunk` و`line` و`ink` و`ink-muted` و`primary` و`on-primary` و`accent` و`ornament`. هي التي تتبدّل مع السمة.
- `gold-800` (ويُستعمل عبر `accent`) هو الذهب الوحيد للنص الصغير على الورق. `gold-600` و`gold-400` للزخارف والحدود وللنص على الخلفيات الداكنة.
- الزر الأساسي زمردي على الورق والسيبيا، وذهبي ونصه `emerald-950` في الليل. استخدم `primary` و`on-primary` ولا تثبّت اللون.
- المشغّل وبطاقة «أكمل القراءة» على `player`، والنص `on-player`، وزر التشغيل الكبير `player-accent`.
- الحالات `success` و`warning` و`error` و`info` تأتي دائمًا مع أيقونة وكلمة. على الورق يتقارب أخضر النجاح وأحمر الخطأ في الإضاءة، فالكلمة والأيقونة هما الفارق لمن يضعف عنده تمييز الألوان. وفي سمة التباين العالي يصير النجاح أزرق.

### سمات القراءة

| السمة | الأرضية | النص | الذهب | متى |
| --- | --- | --- | --- | --- |
| ورق (الافتراضية) | `#F8F2E4` | `#1B2A28` | `#8A6212` | النهار وأغلب الاستخدام |
| ليل | `#0A1413` | `#E8E2D0` | `#D9AE5A` | الظلام؛ ذهب أفتح لا يبهر العين |
| سيبيا | `#F0E2C0` | `#3A2A12` | `#7A4E0E` | قراءة طويلة مريحة للعين |
| تباين عالٍ | `#000000` | `#FFFFFF` | `#FFD54A` | ضعف البصر؛ نص ٧:١ على الأقل وحدود بيضاء تفصل الأسطح |

كل زوج نص وخلفية تذكره ملاحظات الرموز يحقق ٤٫٥:١ في السمات الأربع، و٧:١ في التباين العالي. والعلامات والحدود والحلقات تحقق ٣:١. الاستثناء الوحيد قيمة الذهب الأصلية `ornament` على الورق: ٢٫٩:١. أُبقيت كما هي لأنها زخرفية، ورقم الآية داخل الدائرة بلون `accent` فيبقى مقروءًا.

## الخطوط

ثلاث عائلات، لكلٍّ دور لا يتعدّاه:

- **أميري قرآن** (`quran`): للنص القرآني وحده، وبوزن واحد ٤٠٠. ارتفاع السطر ٢٫٣ ليتّسع للحركات وعلامات الوقف. الأنماط: `quran-page` (٢٥) لصفحة المصحف، و`quran-ayah` (٣٤) لصف الآية والدراسة، و`quran-focus` (٤٤) للكلمة المختارة والحفظ والمشاركة، و`quran-compact` (٢٢) لنتائج البحث وورقة السياق.
- **ريم كوفي** (`kufi`): لأسماء السور، والعناوين الكبيرة، واسم التطبيق. لا يقل عن ٢٠ بكسل، ولا يُستخدم لفقرة أو زر. الأنماط: `display` و`surah-card` و`surah-header` و`app-title`.
- **بلكس سانس عربي** (`sans`): لكل ما عدا ذلك، من أزرار وقوائم وتفسير وإعراب وأرقام. النص الأساسي `body` ١٧، والتفسير `tafsir` ١٨ بسطر ٢٫٠ وعرض لا يتجاوز نحو ٧٠ حرفًا. الحد الأدنى `caption` ١٣، والاستثناء الوحيد `tab-label` ١٢ تحت أيقونته.

كل الأحجام تتبع إعداد حجم الخط في النظام حتى ٢٠٠٪. في وضع السورة يُعاد تدفّق النص عند التكبير، وفي وضع الصفحة تُكبَّر الصفحة كما هي بالقرص.

## التجويد

ثمانية أحكام. لكل حكم لون (`tj-*`) وعلامة خطية وتسمية، فلا يُترك التمييز لحاسة اللون وحدها. وللسمات الداكنة درجات أفتح من الألوان نفسها.

| الحكم | الرمز | العلامة الخطية |
| --- | --- | --- |
| غنّة | `tj-ghunna` | منقّط تحت الحرف |
| إدغام | `tj-idgham` | متصل تحت الحرف |
| إخفاء | `tj-ikhfa` | متقطّع تحت الحرف |
| إقلاب | `tj-iqlab` | مزدوج تحت الحرف |
| قلقلة | `tj-qalqala` | متموّج تحت الحرف |
| مدّ طبيعي | `tj-madd-tabii` | رفيع فوق الحرف |
| مدّ متصل ومنفصل | `tj-madd-wajib` | سميك فوق الحرف |
| مدّ لازم | `tj-madd-lazim` | خطّان فوق الحرف |

- لوّن الحروف التي يقع عليها الحكم فقط، بلفّها في `Tajweed`، ولا تلوّن الكلمة كلها.
- لمسة على الكلمة تفتح ورقة فيها اسم الحكم بعلامته، وشرح سطر واحد، وسبب تطبيقه هنا، وزر «استمع إلى الكلمة».
- مفتاح الأحكام (`TajweedKey compact`) تحت النص، ويُظهر فقط الأحكام الموجودة في الصفحة.
- هذا التوزيع للألوان قرار الهوية، ويختلف عن بعض مصاحف التجويد المطبوعة. إن أُضيف خيار «ألوان مصاحف التجويد المألوفة» فليكن سمة إضافية، لا تعديلًا لهذه الرموز.

## عناصر المصحف والتمييز داخل النص

- **رأس السورة** (`SurahHeader`): إطار مزدوج من `ornament` و`ornament-soft`، ونجمتا الربع، والاسم بريم كوفي ٦٠٠. تحته سطر البسملة في الوسط، عدا التوبة.
- **فاصلة الآية** (`AyahMarker`): دائرة `ornament` رقيقة ورقم الآية بلون `accent`. تمتلئ أثناء تلاوة آيتها. وهي هدف اللمس لفتح أدوات الآية.
- **الهامش**: نجمة الربع لبداية الربع ومعها رقم الحزب. اسم الجزء بريم كوفي فوق خط ذهبي. كلمة «سجدة» بجانب علامة ۩. وشريط زمردي للعلامة المرجعية.
- **علامات الوقف**: تُلمس فيظهر معناها. مـ لازم، لا ممنوع، ج جائز، صلى الوصل أولى، قلى الوقف أولى، والتعانق. ويمكن تفعيل توقّف قصير في التلاوة عندها بمدة يختارها المستخدم.
- **التمييز** (أصناف في `bundle.css`):
  - `qk-hl-ayah`: الآية المسموعة، `highlight-ayah`.
  - `qk-hl-word`: الكلمة المنطوقة، `highlight-word` مع خط سفلي `highlight-word-line`.
  - `qk-hl-select`: الآية المختارة، `selection` مع `selection-line`.
  - `qk-hl-search`: نتيجة البحث، `search-match` مع خط `info`.

  لكل حالة إشارة غير لونية: خط، أو إطار، أو فاصلة ممتلئة.

## البحث والحفظ

- **البحث** (`SearchField` ثم `ModeChips` ثم `SearchSummary` ثم `SearchResult`): حقل بحث بحدّ `line-strong` يصير زمرديًا عند التركيز، وبجانبه ميكروفون «اقرأ جزءًا من الآية». أنواع البحث: كلمة، الجذر، بلا تشكيل، المشتقات، في التفاسير، الموضوعات. نتائج الجذر والمشتقات تُنسب إلى مدوّنة القرآن العربية.
- **الكلمة المطابقة** (`Match`) تُلفّ داخل نص الآية دون المساس بحرف منه: خلفية `search-match` وخط سفلي `info`. الآية تُعرض كاملة؛ إن طالت قُطعت عند نحو ثلاثة أسطر بتلاشٍ ومعها «الآية طويلة · اعرضها كاملة». لا تُلخَّص آية في نتيجة.
- **السياق** (`ContextSheet`): آية، أو ٣، أو ٥، أو السورة، مع الآية المطلوبة بـ`qk-hl-select`. زر «افتح في المصحف» هو الأساسي الوحيد.
- **الحفظ**: `SessionStatus` للخطوة والتكرار، ثم النص، ثم `SessionBar` الزمردي. التكرار يُظهره `RepeatDots` (منجز مملوء، جارٍ حلقة ذهبية، قادم حلقة فارغة) ويُنطق لقارئ الشاشة.
- **الإخفاء** (`ConcealedText`): يُحجب حبر الكلمات فقط بشريط `conceal` وخط سفلي، ويبقى النص تحته كما هو وبطول كلماته الحقيقي. قارئ الشاشة يسمع «الآية مخفية» ولا يسمع النص. الأوضاع: ظاهر · الحالية مخفية · الكل مخفي (`LevelSwitch`).
- **الخطة**: `Stepper` للتكرار والدمج والصمت، و`PlanStep` لتسلسل الجلسة. الدمج التدريجي: كل آية جديدة تُكرَّر ثم تُدمج بما قبلها، فالتسلسل لخمس آيات تسع خطوات (٥ آيات + ٤ دمجات). الأرقام الافتراضية ٧ تكرارات للآية و٣ للدمج، وهي قيم افتراضية يغيّرها المستخدم.
- خطة الحفظ وتكراراتها اختيارات تربوية للتطبيق، وليست حكمًا شرعيًا؛ لا تُنسب إلى مصدر.

## المسافات والزوايا والارتفاع والحركة

- شبكة ٤ بكسل: `space-1` (٤) حتى `space-7` (٤٨).
- الزوايا: الأزرار `radius-button` (١٦)، والبطاقات `radius-card` (٢٤)، والورقة المنزلقة `radius-sheet` (٢٨). الوسوم والمفاتيح دائرية `radius-full`.
- ثلاثة مستويات ارتفاع: حدّ `line` فقط، ثم `shadow-card` للبطاقة، ثم `shadow-sheet` للورقة والمشغّل. لا ظلال على النص ولا على الشعار.
- الحركة: سريعة ١٢٠ م.ث، وعادية ٢٠٠، وبطيئة ٣٢٠، بتخفيف تدريجي بلا ارتداد. قلب الصفحة يتبع إعداد «تقليل الحركة» في النظام، فيصير تلاشيًا.

## الأيقونات

خط بسُمك `icon-stroke` (١٫٧٥) على شبكة ٢٤ (`icon-size`)، أطراف مدوّرة، بلا تعبئة إلا التشغيل والإيقاف. استخدم `Icon` بالاسم (٢٦ أيقونة؛ منها `mic` و`eye` و`sort` و`minus` و`plus` و`context` للبحث والحفظ). ونسخ SVG في مجموعة Icons بحبر `#0E5A52`.

- الأسهم تنعكس مع اتجاه القراءة: «التالي» يشير إلى اليسار. أيقونة التشغيل لا تنعكس.
- أشرطة التقدّم تمتلئ من اليمين.
- لا رموز تعبيرية، ولا صور مساجد أو أهلّة أو فوانيس. الزخرفة الوحيدة نجمة الربع.

## الشعار

- الرمز `Mark`: نجمة الربع (مربعان متراكبان من زخرفة علامات الأحزاب)، والكتاب المفتوح، والنقطة العلوية التي هي موضع القراءة الحالي. هي نفسها شارة «آخر قراءة» داخل التطبيق.
- الصيغ: الأفقي على الورق (الافتراضي)، والأفقي على الزمرد لشاشة البداية والمشاركة، والعمودي للأغلفة. ملفاتها في مجموعة Logos.
- المساحة الآمنة نصف عرض النجمة من كل جانب. أصغر حجم: الرمز ٢٤ بكسل، والأفقي ١٢٠ بكسل عرضًا.
- يزداد سُمك خط النجمة كلما صغر الحجم، وتُحذف النقطة العلوية تحت ٣٢ بكسل (`mark-24.svg`).
- لا يُمطّ، ولا يُدوَّر أو يُمال، ولا يوضع على خلفية قريبة من لونه، ولا تُضاف إليه ظلال أو توهّج.
- الاسم مضبوط حاليًا بخط ريم كوفي ٧٠٠ ومحوَّل إلى مسارات. الكلمة الشعارية النهائية تُرسم يدويًا بحروف مخصّصة قبل الإطلاق.

## إمكانية الوصول

- كل ما يُلمس لا تقل منطقة لمسه عن `target-min` (٤٨)، ولو كان المرئي أصغر (حبّات أنواع البحث ٤٠ مرئيًا). الأزرار `button-height` (٥٢).
- حلقة التركيز: `focus` بسُمك ٢ بكسل بعد فراغ ٢ بكسل.
- أزرار الأيقونات لها `label` دائمًا. المفاتيح والتبويبات بأدوارها الصحيحة (`switch` و`radio` و`tab`).
- قارئ الشاشة يقرأ رقم الآية «الآية ٥»، ويقرأ اسم السورة والموضع قبل النص.
- منع إطفاء الشاشة أثناء القراءة أو التلاوة إعداد اختياري (`Switch`). والتحكم من السماعات وشاشة القفل يتبع عناصر النظام نفسها.

## مستويات الواجهة

- **بسيط**: المصحف، والصوت، وآخر موضع، والعلامة المرجعية، والتفسير عند الطلب.
- **متوسط**: يضيف التجويد والحفظ والختمة والموضوعات.
- **دراسة**: يضيف الإعراب والصرف والجذور والقراءات والمتشابهات وشجرة النحو.

يُبدَّل المستوى من إعداد واحد، ولا يُحذف شيء من بيانات المستخدم عند الرجوع إلى مستوى أبسط.

## المصادر

- النص القرآني في المعاينات من مشروع تنزيل: Tanzil Quran Text (Uthmani, Version 1.1)، برخصة Creative Commons Attribution 3.0. شروطها: يُنقل النص كما هو دون أي تغيير، ويُذكر المصدر مع رابط إلى tanzil.net، ويُحتفظ بإشعار حقوق النشر في كل نسخة وفي كل ملف مشتق منه.
- الجذور وعدد الورود في المعاينات من مدوّنة القرآن العربية (Quranic Arabic Corpus).
- الخطوط كلها برخصة SIL Open Font License: أميري قرآن، وريم كوفي، وبلكس سانس عربي.

---

## Consuming this system (generated — do not edit)

Every path named below is under `project/` in this design system: read `project/api/tokens.md`, not `api/tokens.md`.

`components/bundle.js` defines `window.Quran` (31 components); `components/bundle.css` is its stylesheet; `tokens.css` is every token as a CSS variable plus `@font-face` for the fonts. `components/bundle.css` reads its variables from `tokens.css`. The bundle needs `components/lib/react.production.min.js` (`window.React`), `components/lib/react-dom.production.min.js` (`window.ReactDOM`), loaded before it. Build any UI by mounting these components; never hand-build a control or draw an icon the system provides.

- **Standalone page:** inline `tokens.css` and `components/bundle.css` in a `<style>`, then the library files and `components/bundle.js` as classic scripts (a file containing `</style`, `</script` or `<!--` breaks an inline element: write the sequence `<\/style`, `<\/script` or `\x3C!--` in your copy, or load that file by URL).
- **Design canvas:** bring `components/bundle.css`, `components/bundle.js` and `components/index.d.ts` (for the editor’s props panel) onto the canvas in full, as the canvas type’s design-system components reference says (a server-side copy first where it offers one); load the stylesheet before the script; skip the library files (the artboard supplies React); mount with `<x-import component-from-global-scope="Quran.<Comp>" …>`.
- **Slides deck, or any surface that cannot run the bundle:** tokens and fonts — the values are on `api/tokens.md`; the deck takes `tokens.json` by file path for its colour pickers, and fonts as “Fonts” below says.

Fonts: `tokens.css` loads each font from its file, by path.

- **Design canvas:** copy `tokens.css`, `fonts/AmiriQuran-Regular.woff2`, `fonts/ReemKufi-Variable.woff2`, `fonts/IBMPlexSansArabic-Regular.woff2`, `fonts/IBMPlexSansArabic-Medium.woff2`, `fonts/IBMPlexSansArabic-SemiBold.woff2` and `fonts/IBMPlexSansArabic-Bold.woff2` to the same paths under the canvas’s `project/ds/<folder>/` (`<folder>` is the folder you install this system under; `fonts/AmiriQuran-Regular.woff2` lands on `project/ds/<folder>/fonts/AmiriQuran-Regular.woff2`), in the same call that installs this system. Link that copy of `tokens.css` in the artboard’s `<head>` as `ds/<folder>/tokens.css`, or as Design’s instructions say for an artboard in a folder. If the install’s reply leaves a font out, bring that font in as for any other page.
- **Slides deck:** for each family you use in the deck (`faces` holds at most the number of typefaces Slides’ `deck-files.md` gives), install its file with the system and name the path it lands on as that family’s `src` in `project/deck.json` `faces`, under the key in the Slides column. A deck takes a font as a file only under the rule in Slides’ `fonts.md` (no space or leading underscore in its path, for two): any other font, or one kept by id, is uploaded as `fonts.md` says.
- **Any other page:** one file per family is enough (below: the upright face nearest regular weight; bold and italic synthesize). Fetch it as the fetch column says (Artifact tool `read`, that id or path as `path`), upload it as an asset (`publish`, `file_path`, `asset:true`) and declare it with an `@font-face { font-family: "<family>"; src: url(<uploaded>) }` rule.

| family | file | fetch | CSS | Slides `faces` key |
| --- | --- | --- | --- | --- |
| Amiri Quran | `fonts/AmiriQuran-Regular.woff2` (weight 400) | `read` the file with `project/` in front | `var(--font-quran)` | `amiri-quran` |
| Reem Kufi | `fonts/ReemKufi-Variable.woff2` (weight 400 700) | `read` the file with `project/` in front | `var(--font-kufi)` | `reem-kufi` |
| IBM Plex Sans Arabic | `fonts/IBMPlexSansArabic-Regular.woff2` (weight 400) | `read` the file with `project/` in front | `var(--font-kufi)` | `ibm-plex-sans-arabic` |

**Read, per thing:** a component’s props, parts and examples: `api/components/<Comp>.md`; token values: `api/tokens.md`; stored assets and their paths: `api/assets/<Group>.md`. After this README, fetch the cards and fonts you need in ONE message as parallel calls — none depends on another.

**Two rules.** Before you use a thing — a component, a token group, an icon, an asset — read its card from the index below; a value you did not read from a card is a guess. `tokens.json`, `manifest.json`, `components/index.d.ts` and `design-system.json` are sources for tools: hand them over. `components/<Comp>/README.md` and `assets/<Group>/README.md` are the long-form second read a card links to; `SKILL.md` and `artifact-type/` beside them are authoring guidance, not needed to consume the system.

## Index (generated — do not edit)

**Tokens**

- `api/tokens.md` — Every token: surface, text, fill, palette, type, spacing, radius, shadow, size. (14.8k)

**Icons and assets**

- `api/assets/Logos.md` — 13 files, by asset id. (2.8k)
- `api/assets/Icons.md` — 26 files, by asset id. (3.0k)

**Components** (`api/components/<Comp>.md`, 31)

- **الهوية**: `Mark` — رمز التطبيق: نجمة الربع (مربعان متراكبان) تحتضن كتابًا مفتوحًا، وفوقه النقطة العلوية التي تعني «موضع القراءة الحالي» · `Lockup` — الرمز مع الاسم «القرآن الكريم» بخط ريم كوفي ٧٠٠. الرمز على يمين الاسم لأن القراءة تبدأ منه · `Icon` — مجموعة أيقونات خطية على شبكة ٢٤: خط ١٫٧٥ بأطراف مدوّرة، بلا تعبئة إلا التشغيل والإيقاف. تأخذ لونها من currentColor
- **الإجراءات**: `Button` — الأزرار: ارتفاع ٥٢، زوايا ١٦، نص ١٧ نصف عريض. الارتفاع الأدنى ٤٨ والنص لا ينقص عن ١٧ · `IconButton` — زر أيقونة دائري، ٤٨ بكسل افتراضيًا. label إلزامي لأنه الاسم الذي يقرؤه قارئ الشاشة
- **التحكم**: `LevelSwitch` — مفتاح مستوى الواجهة: بسيط · متوسط · دراسة. يغيّر الأدوات الظاهرة في التطبيق كله من إعداد واحد · `Tag` — وسم تصنيف للعلامات والملاحظات والمجموعات. لكل تصنيف شكل ولون واسم، فلا يُترك التمييز للون وحده · `Switch` — مفتاح تشغيل وإيقاف للإعدادات، ٥٦×٣٢ داخل صف ارتفاعه ٤٨. عند التفعيل تكون الدائرة على اليسار والمسار زمرديًا
- **المصحف**: `AyahMarker` — فاصلة الآية: دائرة ذهبية رقيقة (ornament) ورقم الآية بداخلها بخط الواجهة ٦٠٠ بلون accent · `QuranText` — حاوية النص القرآني بخط أميري قرآن. size: page (٢٥/٢٫٣ لصفحة المصحف)، ayah (٣٤/٢٫٣)، focus (٤٤/٢)، compact (٢٢/٢٫٢ لنتائج البحث وورقة السياق والحفظ) · `SurahHeader` — رأس السورة: إطار مزدوج (خارجي ١٫٥ بلون ornament وداخلي ١ بلون ornament-soft) ونجمتا الربع على الجانبين، والاسم بخط ريم كوفي ٦٠٠ بلون primary · `AyahRow` — الآية بطاقةً مستقلة لوضع الدراسة والبحث والعلامات: فاصلتها، ثم ثلاثة أفعال (تشغيل من هنا، علامة مرجعية، مركز الدراسة)، ثم النص بحجم quran-ayah · `SurahListItem` — صف فهرس السور: الرقم داخل نجمة الربع، والاسم بخط ريم كوفي، ثم «مكية/مدنية · عدد الآيات»، وصفحة البداية · `TajweedKey` — مفتاح أحكام التجويد الثمانية. لكل حكم لون (tj-*) وعلامة خطية واسم، فلا يُترك التمييز لحاسة اللون وحدها
- **الصوت والتقدّم**: `ProgressBar` — شريط تقدّم يمتلئ من بداية السطر، أي من اليمين، مثل اتجاه القراءة · `MiniPlayer` — بطاقة المشغّل الزمردية: السورة والآية بخط ريم كوفي، واسم القارئ، والسرعة، وشريط تقدّم ذهبي، وخمسة أزرار: تكرار، والآية السابقة، وتشغيل/إيقاف (ذهب ٦٠ بكسل)، وال… · `ContinueCard` — بطاقة «أكمل القراءة» في الرئيسية: زمرد بنجمة ذهبية خافتة في الزاوية، واسم السورة بخط ريم كوفي ٣٢، والموضع، والتقدّم في المصحف، وزر «تابع القراءة» · `ResourceRow` — صف في مدير الموارد: تفاسير، وتلاوات، وروايات، وموارد لغوية
- **التنقل والدراسة**: `TabBar` — شريط التنقل السفلي بخمسة أقسام: الرئيسية، المصحف، الاستماع، الدراسة، المزيد. القسم النشط بحبّة زمردية فاتحة خلف أيقونته · `WordSheet` — الورقة المنزلقة لدراسة كلمة: تبويبات (النص، التفسير، الإعراب، الصرف، التجويد)، ثم الكلمة بحجم quran-focus، ثم صفوف «تسمية · قيمة»
- **البحث**: `SearchField` — حقل البحث: أيقونة، ونص ١٨ نصف عريض، وزر الميكروفون ٤٨ لـ«اقرأ جزءًا من الآية». ارتفاعه ٥٦، وحدّه line-strong، ويصير زمرديًا ٢ بكسل حين يأخذ التركيز · `ModeChips` — حبّات أنواع البحث: كلمة، الجذر، بلا تشكيل، المشتقات، في التفاسير، الموضوعات. واحد منها مختار دائمًا · `SearchSummary` — سطر ما بحثتَ عنه وعدد نتائجه، وفي آخره زر الترتيب (ترتيب المصحف، الأقرب، الأكثر ورودًا) · `SearchResult` — بطاقة نتيجة واحدة: الموضع («البقرة · الآية ٤٥»)، وزرّان (سياق الآية، افتح في المصحف)، ثم الآية كاملة بخط المصحف ٢٢ · `ContextSheet` — ورقة منزلقة تُظهر الآية بين ما قبلها وما بعدها، تُفتح من زر «سياق الآية» في نتيجة البحث
- **الحفظ**: `RepeatDots` — نقاط عدّاد التكرار: المنجز مملوء بالزمرد، والجاري حلقة ذهبية ٣ بكسل بداخلها ذهب فاتح، والقادم حلقة فارغة بحدّ line-strong. الأشكال الثلاثة تختلف بالتعبئة والسُ… · `SessionStatus` — بطاقة رأس جلسة الحفظ: «الخطوة ٤ من ٩» بلون accent، ثم «الآية ٣ · التكرار ٤ من ٧»، وفي آخرها RepeatDots · `ConcealedText` — نص الحفظ بعد حجب حبره. لا يُحذف شيء: النص باقٍ كلمةً كلمة تحت شريط conceal (خط سفلي line-strong وشريط بطول الكلمة)، فيبقى موضع كل كلمة وطولها ظاهرين ليتذكّر ال… · `SessionBar` — الشريط الزمردي العائم أسفل جلسة الحفظ: إيقاف مؤقت/متابعة (ذهب ٥٢)، وما يجري الآن، وزر الخطوة التالية (٤٨) · `Stepper` — رقم يُعدَّل بزرّي إنقاص وزيادة، كلٌّ منهما بحجم لمس ٤٨. للإعدادات الصغيرة: عدد التكرار، وتكرار الدمج، ومدة الصمت · `PlanStep` — صف من تسلسل الجلسة في خطة الحفظ: الآية ثم تكرارها، وبعد كل آية جديدة «دمج» بما سبقها: ١ ثم ٢ ثم ١–٢ معًا ثم ٣ ثم ١–٣ معًا، وهكذا

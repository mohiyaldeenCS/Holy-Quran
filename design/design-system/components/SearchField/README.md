# SearchField

حقل البحث: أيقونة، ونص ١٨ نصف عريض، وزر الميكروفون ٤٨ لـ«اقرأ جزءًا من الآية». ارتفاعه ٥٦، وحدّه `line-strong`، ويصير زمرديًا ٢ بكسل حين يأخذ التركيز.

- `value` / `onChange` أو `defaultValue`، و`onVoice` عند لمس الميكروفون (اسمه لقارئ الشاشة: «ابحث بالصوت: اقرأ جزءًا من الآية»).
- `placeholder` و`label` الافتراضيان «ابحث في القرآن». الحقل `type=search` مع `enterKeyHint=search`.
- يسبق أنواع البحث (`ModeChips`) ثم `SearchSummary` ثم النتائج.

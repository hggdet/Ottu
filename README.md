# وين

تطبيق خرائط iPhone **وين** مبني بـ **SwiftUI + MapLibre Native**، بواجهة عربية RTL وترجمات الإنجليزية والكردية السورانية. نقطة البداية الافتراضية بغداد.

## الموجود في هذه النسخة

- خريطة ملء الشاشة بنمطي OpenFreeMap الفاتح والداكن، مع إسناد مرئي ومدمج لمصادر الخريطة.
- بحث أماكن عبر Photon مع تضمين الأماكن المحفوظة والمحلية في نتائج البحث.
- تحديد المكان ومشاركة رابط إحداثيات OpenStreetMap.
- المفضلة والأماكن التي يضيفها المستخدم تحفظ محليًا على الجهاز.
- إضافة مكان بالضغط المطوّل على الخريطة.
- طلب موقع iPhone عند اختيار «موقعي»؛ إذن الموقع اختياري.
- مسار قيادة مرسوم على الخريطة وملخص مسافة/زمن عبر واجهة OSRM العامة.
- تنزيل نطاق صغير حول مركز الخريطة لاستخدامه دون اتصال عبر MapLibre؛ التنزيل **ليس تغطية كاملة للعراق**.
- نموذج بلاغات الزحام والحواجز وإغلاق الطرق والمخاطر، مع سجل محلي على الجهاز.
- WidgetKit يعرض حتى ثلاثة أماكن مفضلة، ويشارك مخزن البيانات مع التطبيق عبر App Group.
- ترجمات واجهة عربية وإنجليزية وكردية سورانية، مع شاشة إعدادات لاختيار اللغة والمظهر أو اتباع إعداد النظام.
- إدارة الأماكن المحلية من الإعدادات، مع إزالة الأماكن المحفوظة، وإدارة تنزيل خريطة المنطقة دون اتصال وحذفه.
- XcodeGen وGitHub Actions للبناء وإنتاج IPA غير موقّع.

## حدود النسخة الحالية

هذه نسخة أولية قابلة للبناء وليست خدمة خرائط مجتمعية مكتملة. الأماكن والبلاغات محفوظة على الجهاز فقط: لا حسابات أو خادم أو مزامنة بين المستخدمين، والبلاغات لا تظهر على الخريطة العامة. تنزيل الخرائط يقتصر على نطاق صغير حول مركز الخريطة، وليس حزمة كاملة للعراق. التوجيه يستخدم موقعك إذا كان متاحًا، وإلا يبدأ من مركز الخريطة الحالي؛ يستخدم خدمة OSRM العامة ولا يعرض تعليمات انعطاف خطوة بخطوة، وتوفر الخدمة وتغطيتها غير مضمونين. البحث والتوجيه وتنزيل الخرائط يحتاج اتصالًا بالإنترنت عند أول استخدام، كما أن مزودي الخرائط وخدمات الأطراف الثالثة قد يغيرون التوفر أو شروط الاستخدام.

## البنية

```text
Sources/Ottu/
├── App/                 # تشغيل SwiftUI واتجاه RTL
├── Config/              # نمط ومركز الخريطة
├── Features/Map/        # الشاشة الرئيسية وخريطة MapLibre
├── Features/Places/     # تفاصيل المكان، المحفوظات، إضافة مكان والبلاغات
├── Features/Settings/   # إعدادات اللغة والمظهر وإدارة البيانات المحلية والخرائط
├── Models/              # المكان والإحداثيات والبلاغ
└── Services/            # البحث، التوجيه، الموقع، التخزين المحلي والأوفلاين
Sources/OttuWidget/      # WidgetKit للمفضلة
Resources/               # العربية والإنجليزية والكردية وبيانات الأماكن الأولية
Support/                 # Info.plist وApp Group entitlements
Tests/                   # اختبارات نماذج أساسية
.github/workflows/       # البناء والاختبارات على macOS
```

## البناء محليًا على macOS

المتطلبات: Xcode 16 أو أحدث وXcodeGen. من مجلد المشروع:

```sh
brew install xcodegen
xcodegen generate --spec project.yml
xcodebuild -resolvePackageDependencies -project Ottu.xcodeproj -scheme Ottu
xcodebuild test -project Ottu.xcodeproj -scheme Ottu \
  -destination 'platform=iOS Simulator,name=iPhone 16' CODE_SIGNING_ALLOWED=NO
xcodebuild -project Ottu.xcodeproj -scheme Ottu -sdk iphoneos \
  -destination 'generic/platform=iOS' CODE_SIGNING_ALLOWED=NO build
```

## GitHub Actions وIPA

يعمل سير البناء عند الدفع إلى `main`، وطلبات الدمج، أو التشغيل اليدوي. ينشئ `Ottu.xcodeproj` بواسطة XcodeGen، وينفذ الاختبارات، ويبني تطبيق **وين** وإضافة الودجت، ثم يحفظ `wain-unsigned.ipa` كـ artifact باسم `wain-unsigned-ipa` لمدة 14 يومًا، ويمكن تنزيله من صفحة Actions في المستودع. الملف **غير موقّع** ولا يمكن تثبيته أو توزيعه قبل إعداد شهادة وملف provisioning مناسبين. يتطلب التوقيع أيضًا تسجيل App Group `group.iq.ottu.shared` ضمن فريق Apple Developer نفسه للتطبيق والودجت، واستبدال معرّف الحزمة الافتراضي إذا كان مستخدمًا مسبقًا.

## مصادر الخرائط والبيانات

- الخريطة: `https://tiles.openfreemap.org/styles/liberty` ونمط `dark`.
- البحث: Photon عبر `https://photon.komoot.io/api/`.
- التوجيه: OSRM demo endpoint عبر `https://router.project-osrm.org/`.
- بيانات الخرائط: OpenStreetMap؛ أبقِ إسناد MapLibre/OpenFreeMap/OSM ظاهرًا.
- الأيقونات: أصول Iconly الأصلية المجانية `Location` و`Category` و`Setting` بنمط `Light`، ضمن `Sources/Ottu/Assets.xcassets`؛ يُستحسن الإسناد وفق [دليل الترخيص](https://iconly.pro/pages/licensing-guide).
- MapLibre Native مضاف كاعتماد Swift Package ومثبت على revision في `project.yml`.

راجع شروط واستخدام مزودي الأطراف الثالثة وسعاتهم قبل إطلاق عام أو تنزيل كميات كبيرة من البلاطات.

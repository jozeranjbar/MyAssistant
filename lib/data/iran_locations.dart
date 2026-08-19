/// دیتاست استان‌ها و شهرهای اصلی ایران به همراه مختصات جغرافیایی.
/// در صورت نیاز می‌توانید شهرهای بیشتری به هر استان اضافه کنید؛
/// فقط کافیست یک آیتم جدید با name/lat/lng به لیست cities همان استان اضافه کنید.
class IranCity {
  final String name;
  final double lat;
  final double lng;
  const IranCity(this.name, this.lat, this.lng);
}

class IranProvince {
  final String name;
  final List<IranCity> cities;
  const IranProvince(this.name, this.cities);
}

const List<IranProvince> iranProvinces = [
  IranProvince('تهران', [
    IranCity('تهران', 35.6892, 51.3890),
    IranCity('شهریار', 35.6597, 51.0566),
    IranCity('ورامین', 35.3260, 51.6453),
    IranCity('اسلامشهر', 35.5449, 51.2244),
  ]),
  IranProvince('اصفهان', [
    IranCity('اصفهان', 32.6546, 51.6680),
    IranCity('کاشان', 33.9850, 51.4100),
    IranCity('نجف‌آباد', 32.6339, 51.3697),
    IranCity('خمینی‌شهر', 32.7009, 51.5292),
  ]),
  IranProvince('فارس', [
    IranCity('شیراز', 29.5918, 52.5837),
    IranCity('مرودشت', 29.8720, 52.8055),
    IranCity('جهرم', 28.5000, 53.5602),
  ]),
  IranProvince('خراسان رضوی', [
    IranCity('مشهد', 36.2605, 59.6168),
    IranCity('نیشابور', 36.2133, 58.7958),
    IranCity('سبزوار', 36.2126, 57.6788),
  ]),
  IranProvince('آذربایجان شرقی', [
    IranCity('تبریز', 38.0800, 46.2919),
    IranCity('مراغه', 37.3937, 46.2411),
    IranCity('میانه', 37.4222, 47.7128),
  ]),
  IranProvince('آذربایجان غربی', [
    IranCity('ارومیه', 37.5527, 45.0761),
    IranCity('خوی', 38.5503, 44.9531),
    IranCity('مهاباد', 36.7628, 45.7211),
  ]),
  IranProvince('البرز', [
    IranCity('کرج', 35.8400, 50.9391),
    IranCity('نظرآباد', 35.9505, 50.6081),
  ]),
  IranProvince('ایلام', [
    IranCity('ایلام', 33.6374, 46.4227),
    IranCity('دهلران', 32.6941, 47.2679),
  ]),
  IranProvince('بوشهر', [
    IranCity('بوشهر', 28.9234, 50.8203),
    IranCity('برازجان', 29.2632, 51.2100),
  ]),
  IranProvince('چهارمحال و بختیاری', [
    IranCity('شهرکرد', 32.3256, 50.8644),
    IranCity('بروجن', 31.9679, 51.2977),
  ]),
  IranProvince('خراسان جنوبی', [
    IranCity('بیرجند', 32.8649, 59.2262),
  ]),
  IranProvince('خراسان شمالی', [
    IranCity('بجنورد', 37.4747, 57.3290),
  ]),
  IranProvince('خوزستان', [
    IranCity('اهواز', 31.3183, 48.6706),
    IranCity('آبادان', 30.3392, 48.3043),
    IranCity('دزفول', 32.3830, 48.4041),
  ]),
  IranProvince('زنجان', [
    IranCity('زنجان', 36.6736, 48.4787),
    IranCity('ابهر', 36.1497, 49.2178),
  ]),
  IranProvince('سمنان', [
    IranCity('سمنان', 35.5729, 53.3971),
    IranCity('شاهرود', 36.4181, 54.9760),
  ]),
  IranProvince('سیستان و بلوچستان', [
    IranCity('زاهدان', 29.4963, 60.8629),
    IranCity('چابهار', 25.2919, 60.6430),
    IranCity('زابل', 31.0296, 61.4996),
  ]),
  IranProvince('قزوین', [
    IranCity('قزوین', 36.2797, 50.0049),
  ]),
  IranProvince('قم', [
    IranCity('قم', 34.6416, 50.8746),
  ]),
  IranProvince('کردستان', [
    IranCity('سنندج', 35.3111, 46.9923),
    IranCity('سقز', 36.2494, 46.2727),
  ]),
  IranProvince('کرمان', [
    IranCity('کرمان', 30.2839, 57.0834),
    IranCity('رفسنجان', 30.4067, 55.9938),
    IranCity('سیرجان', 29.4519, 55.6814),
  ]),
  IranProvince('کرمانشاه', [
    IranCity('کرمانشاه', 34.3277, 47.0778),
    IranCity('اسلام‌آباد غرب', 34.1108, 46.5289),
  ]),
  IranProvince('کهگیلویه و بویراحمد', [
    IranCity('یاسوج', 30.6682, 51.5880),
  ]),
  IranProvince('گلستان', [
    IranCity('گرگان', 36.8456, 54.4295),
    IranCity('گنبد کاووس', 37.2506, 55.1734),
  ]),
  IranProvince('گیلان', [
    IranCity('رشت', 37.2809, 49.5832),
    IranCity('بندر انزلی', 37.4739, 49.4614),
    IranCity('لاهیجان', 37.2081, 50.0027),
  ]),
  IranProvince('لرستان', [
    IranCity('خرم‌آباد', 33.4878, 48.3558),
    IranCity('بروجرد', 33.8973, 48.7514),
  ]),
  IranProvince('مازندران', [
    IranCity('ساری', 36.5633, 53.0601),
    IranCity('بابل', 36.5513, 52.6790),
    IranCity('آمل', 36.4695, 52.3512),
    IranCity('قائم‌شهر', 36.4642, 52.8600),
  ]),
  IranProvince('مرکزی', [
    IranCity('اراک', 34.0913, 49.6892),
    IranCity('ساوه', 35.0213, 50.3564),
  ]),
  IranProvince('هرمزگان', [
    IranCity('بندرعباس', 27.1865, 56.2808),
    IranCity('قشم', 26.9581, 56.2719),
    IranCity('میناب', 27.1467, 57.0801),
  ]),
  IranProvince('همدان', [
    IranCity('همدان', 34.7992, 48.5146),
    IranCity('ملایر', 34.2967, 48.8228),
  ]),
  IranProvince('یزد', [
    IranCity('یزد', 31.8974, 54.3569),
    IranCity('میبد', 32.2500, 54.0167),
  ]),
];

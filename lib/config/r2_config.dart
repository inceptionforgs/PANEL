class R2Config {
  static const defaultSingerName = "mewati";
  static const defaultCategory = "Mewati";
  static const mp3Ext = ".mp3";

  static const coverPool = <String>[
    "https://vryngmkjnposksoaknik.supabase.co/storage/v1/object/public/Songs/Artist%20image/F6247147-00EE-4076-AB8E-2E905B4EADEE.png",
    "https://vryngmkjnposksoaknik.supabase.co/storage/v1/object/public/Songs/Artist%20image/704466A5-30B4-4072-96CE-9B30CA241075.png",
    "https://vryngmkjnposksoaknik.supabase.co/storage/v1/object/public/Songs/Artist%20image/A93547AA-55F4-47A1-A142-B109318883D5.png",
    "https://vryngmkjnposksoaknik.supabase.co/storage/v1/object/public/Songs/Artist%20image/DCADFACB-4A37-433E-8FB8-19E6EC44B8FA.png",
    "https://vryngmkjnposksoaknik.supabase.co/storage/v1/object/public/Songs/Artist%20image/F819CF0F-FBCD-492C-9744-A19F64B4C78C.png",
    "https://vryngmkjnposksoaknik.supabase.co/storage/v1/object/public/Songs/Artist%20image/753FE511-1356-4F77-9A7B-06772D5C30B4.png",
    "https://vryngmkjnposksoaknik.supabase.co/storage/v1/object/public/Songs/Artist%20image/A1BCF55F-76C2-4B96-924E-37E1256040CD.png",
    "https://vryngmkjnposksoaknik.supabase.co/storage/v1/object/public/Songs/Artist%20image/0F416243-58A1-4831-ADE0-78E6B1CEE75B.png",
    "https://vryngmkjnposksoaknik.supabase.co/storage/v1/object/public/Songs/Artist%20image/766FD01B-4646-43C8-B9A4-03976F225364.png",
    "https://vryngmkjnposksoaknik.supabase.co/storage/v1/object/public/Songs/Artist%20image/6CF9156E-E9CF-48A1-84DE-651FC5E95C51.png",
    "https://vryngmkjnposksoaknik.supabase.co/storage/v1/object/public/Songs/Artist%20image/30376E3E-3EF0-4FD0-8EE2-03D4424CF0DF.png",
    "https://vryngmkjnposksoaknik.supabase.co/storage/v1/object/public/Songs/Artist%20image/BDCA32D9-C333-4022-B8A6-B6DA3E59726B.png",
    "https://vryngmkjnposksoaknik.supabase.co/storage/v1/object/public/Songs/Artist%20image/1D0308A2-660D-45BF-886C-C232C7A1B29E.png",
    "https://vryngmkjnposksoaknik.supabase.co/storage/v1/object/public/Songs/Artist%20image/12E375B8-FF48-48A9-B072-CF7CD032683C.png",
    "https://vryngmkjnposksoaknik.supabase.co/storage/v1/object/public/Songs/Artist%20image/3143DC2E-B48F-40C9-A687-9CA21D812536.png",
    "https://vryngmkjnposksoaknik.supabase.co/storage/v1/object/public/Songs/Artist%20image/47E7709E-4687-449D-BFD3-C01FCDEF31D9.png",
    "https://vryngmkjnposksoaknik.supabase.co/storage/v1/object/public/Songs/Artist%20image/48691f67-74c1-4d45-a955-8023e16badd8.jpeg",
  ];

  static String zipperCover(int oneBasedIndex) {
    final n = coverPool.length;
    final pos = (oneBasedIndex - 1) % n;
    final idx = pos.isEven ? pos ~/ 2 : n - 1 - (pos ~/ 2);
    return coverPool[idx];
  }
}

# Sharp model driver map for SNMP auto-install.
# SNMP text is matched to the longest model token in these packages.
# MX-2300, MX-2600 and MX-3600 are one package. The INF has no MX-3600N.
# MX-M465 64-bit is the 2013 INF inside the MX-M5071 package. The 32-bit INF is not published.
# MX-M5070 PS lists the same models as PCL6. SNMP install uses PCL6.
# The Windows port is created with SNMP enabled (community public).

$script:SharpModelPackages = @{
    't1-ar' = @{
        File = 'SHARP_T1_AR-M236_02.00.00.00.zip'
        Url = 'https://github.com/lanyen007/FLGPQT/releases/download/drivers-sharp-snmp-20261109/SHARP_T1_AR-M236_02.00.00.00.zip'
        Sha256 = 'dba3ea23bbd3966a0e8cf4ab51ba635049f1ac7f73bb4e464398fa6d54495f03'
        Version = '02.00.00.00'
    }
    'spdl-ar' = @{
        File = 'SHARP_SPDL2_AR-266_01.00.05.001.zip'
        Url = 'https://github.com/lanyen007/FLGPQT/releases/download/drivers-sharp-snmp-20261109/SHARP_SPDL2_AR-266_01.00.05.001.zip'
        Sha256 = 'ded3209317e24deb142d8ca2a2037c4e840e3ea48e64e624c8f53b761883cb9d'
        Version = '01.00.05.001'
    }
    'pcl6-mx1800' = @{
        File = 'SHARP_PCL6_MX-1800_01.00.00.01.zip'
        Url = 'https://github.com/lanyen007/FLGPQT/releases/download/drivers-sharp-snmp-20261109/SHARP_PCL6_MX-1800_01.00.00.01.zip'
        Sha256 = '61177d3242297a4437ae8eed814df7d48effe8a31469a0695463c38e435751c8'
        Version = '01.00.00.01'
    }
    'gdi-m260' = @{
        File = 'SHARP_GDI_MX-M260FG_02.00.00.00.zip'
        Url = 'https://github.com/lanyen007/FLGPQT/releases/download/drivers-sharp-snmp-20261109/SHARP_GDI_MX-M260FG_02.00.00.00.zip'
        Sha256 = 'e691a93c639f80fb230b0a74b125bb53cbc4f9ae612c416cf8b0959932d43f27'
        Version = '02.00.00.00'
    }
    'pcl6-m452' = @{
        File = 'SHARP_PCL6_MX-M452N_01.00.00.01.zip'
        Url = 'https://github.com/lanyen007/FLGPQT/releases/download/drivers-sharp-snmp-20261109/SHARP_PCL6_MX-M452N_01.00.00.01.zip'
        Sha256 = '281b5d3affa7dd5543ecbb4140791260f359837db47c0223ef2fb8d137abda4b'
        Version = '01.00.00.01'
    }
    'pcl6-m266' = @{
        File = 'SHARP_PCL6_MX-M266N_01.01.00.06.zip'
        Url = 'https://github.com/lanyen007/FLGPQT/releases/download/drivers-sharp-snmp-20261109/SHARP_PCL6_MX-M266N_01.01.00.06.zip'
        Sha256 = '2a537d7dc2376d6d07f3e153f5ebd8b8d9276dac037a55a09ba2bd38a94a65df'
        Version = '01.01.00.06'
    }
    'pcl6-m5070' = @{
        File = 'SHARP_PCL6_MX-M5070_09.01.18.61.zip'
        Url = 'https://github.com/lanyen007/FLGPQT/releases/download/drivers-sharp-snmp-20261109/SHARP_PCL6_MX-M5070_09.01.18.61.zip'
        Sha256 = 'f6ae992472a3d0cc0de5e195269419db184f28f621008c328fe9e65a04258cea'
        Version = '09.01.18.61'
    }
    'pcl6-m5071' = @{
        File = 'SHARP_PCL6_MX-M5071_08.05.04.33.zip'
        Url = 'https://github.com/lanyen007/FLGPQT/releases/download/drivers-sharp-snmp-20261109/SHARP_PCL6_MX-M5071_08.05.04.33.zip'
        Sha256 = '4f135e5a13fbdf3e566034b27f68800465d4a0b3a2a50c85f32c1310d4c29340'
        Version = '08.05.04.33'
    }
}

$script:SharpModelDrivers = @{
    'AR266FP' = @{ Name = 'SHARP AR-266FP SPDL2_T1'; Package = 'spdl-ar' }
    'AR266S' = @{ Name = 'SHARP AR-266S SPDL2_T1'; Package = 'spdl-ar' }
    'AR267FP' = @{ Name = 'SHARP AR-267FP SPDL2_T1'; Package = 'spdl-ar' }
    'AR267S' = @{ Name = 'SHARP AR-267S SPDL2_T1'; Package = 'spdl-ar' }
    'AR311FP' = @{ Name = 'SHARP AR-311FP SPDL2_T1'; Package = 'spdl-ar' }
    'AR311N' = @{ Name = 'SHARP AR-311N SPDL2_T1'; Package = 'spdl-ar' }
    'AR311S' = @{ Name = 'SHARP AR-311S SPDL2_T1'; Package = 'spdl-ar' }
    'AR317FP' = @{ Name = 'SHARP AR-317FP SPDL2_T1'; Package = 'spdl-ar' }
    'AR317S' = @{ Name = 'SHARP AR-317S SPDL2_T1'; Package = 'spdl-ar' }
    'AR351FP' = @{ Name = 'SHARP AR-351FP SPDL2_T1'; Package = 'spdl-ar' }
    'AR351N' = @{ Name = 'SHARP AR-351N SPDL2_T1'; Package = 'spdl-ar' }
    'AR351S' = @{ Name = 'SHARP AR-351S SPDL2_T1'; Package = 'spdl-ar' }
    'AR451FP' = @{ Name = 'SHARP AR-451FP SPDL2_T1'; Package = 'spdl-ar' }
    'AR451N' = @{ Name = 'SHARP AR-451N SPDL2_T1'; Package = 'spdl-ar' }
    'AR451S' = @{ Name = 'SHARP AR-451S SPDL2_T1'; Package = 'spdl-ar' }
    'AR555M' = @{ Name = 'SHARP AR-555M SPDL2_T1'; Package = 'spdl-ar' }
    'AR555S' = @{ Name = 'SHARP AR-555S SPDL2_T1'; Package = 'spdl-ar' }
    'AR5625' = @{ Name = 'SHARP AR-5625 T1'; Package = 't1-ar' }
    'AR5631' = @{ Name = 'SHARP AR-5631 T1'; Package = 't1-ar' }
    'AR625M' = @{ Name = 'SHARP AR-625M SPDL2_T1'; Package = 'spdl-ar' }
    'AR625S' = @{ Name = 'SHARP AR-625S SPDL2_T1'; Package = 'spdl-ar' }
    'AR705M' = @{ Name = 'SHARP AR-705M SPDL2_T1'; Package = 'spdl-ar' }
    'AR705S' = @{ Name = 'SHARP AR-705S SPDL2_T1'; Package = 'spdl-ar' }
    'ARB351' = @{ Name = 'SHARP AR-B351 PCL6'; Package = 'pcl6-m5070' }
    'ARB351F' = @{ Name = 'SHARP AR-B351F PCL6'; Package = 'pcl6-m5070' }
    'ARB351W' = @{ Name = 'SHARP AR-B351W PCL6'; Package = 'pcl6-m5070' }
    'ARB352P' = @{ Name = 'SHARP AR-B352P PCL6'; Package = 'pcl6-m5070' }
    'ARB353P' = @{ Name = 'SHARP AR-B353P PCL6'; Package = 'pcl6-m5070' }
    'ARB451' = @{ Name = 'SHARP AR-B451 PCL6'; Package = 'pcl6-m5070' }
    'ARB451F' = @{ Name = 'SHARP AR-B451F PCL6'; Package = 'pcl6-m5070' }
    'ARB451W' = @{ Name = 'SHARP AR-B451W PCL6'; Package = 'pcl6-m5070' }
    'ARB452P' = @{ Name = 'SHARP AR-B452P PCL6'; Package = 'pcl6-m5070' }
    'ARB453P' = @{ Name = 'SHARP AR-B453P PCL6'; Package = 'pcl6-m5070' }
    'ARM236' = @{ Name = 'SHARP AR-M236 T1'; Package = 't1-ar' }
    'ARM237' = @{ Name = 'SHARP AR-M237 T1'; Package = 't1-ar' }
    'ARM256' = @{ Name = 'SHARP AR-M256 T1'; Package = 't1-ar' }
    'ARM257' = @{ Name = 'SHARP AR-M257 T1'; Package = 't1-ar' }
    'ARM276' = @{ Name = 'SHARP AR-M276 T1'; Package = 't1-ar' }
    'ARM277' = @{ Name = 'SHARP AR-M277 T1'; Package = 't1-ar' }
    'ARM316' = @{ Name = 'SHARP AR-M316 T1'; Package = 't1-ar' }
    'ARM317' = @{ Name = 'SHARP AR-M317 T1'; Package = 't1-ar' }
    'ARM452U' = @{ Name = 'SHARP AR-M452U PCL6'; Package = 'pcl6-m452' }
    'BP10C20' = @{ Name = 'SHARP BP-10C20 PCL6'; Package = 'pcl6-m5071' }
    'BP20C20' = @{ Name = 'SHARP BP-20C20 PCL6'; Package = 'pcl6-m5071' }
    'BP20C25' = @{ Name = 'SHARP BP-20C25 PCL6'; Package = 'pcl6-m5071' }
    'BP20M22' = @{ Name = 'SHARP BP-20M22 PCL6'; Package = 'pcl6-m5071' }
    'BP20M24' = @{ Name = 'SHARP BP-20M24 PCL6'; Package = 'pcl6-m5071' }
    'BP20M24L' = @{ Name = 'SHARP BP-20M24L PCL6'; Package = 'pcl6-m5071' }
    'BP20M28' = @{ Name = 'SHARP BP-20M28 PCL6'; Package = 'pcl6-m5071' }
    'BP20M31' = @{ Name = 'SHARP BP-20M31 PCL6'; Package = 'pcl6-m5071' }
    'BP21M22' = @{ Name = 'SHARP BP-21M22 PCL6'; Package = 'pcl6-m5071' }
    'BP30C25' = @{ Name = 'SHARP BP-30C25 PCL6'; Package = 'pcl6-m5071' }
    'BP30M28' = @{ Name = 'SHARP BP-30M28 PCL6'; Package = 'pcl6-m5071' }
    'BP30M31' = @{ Name = 'SHARP BP-30M31 PCL6'; Package = 'pcl6-m5071' }
    'BP30M35' = @{ Name = 'SHARP BP-30M35 PCL6'; Package = 'pcl6-m5071' }
    'DXC310' = @{ Name = 'SHARP DX-C310 PCL6'; Package = 'pcl6-mx1800' }
    'DXC311' = @{ Name = 'SHARP DX-C311 PCL6'; Package = 'pcl6-mx1800' }
    'DXC380' = @{ Name = 'SHARP DX-C380 PCL6'; Package = 'pcl6-mx1800' }
    'DXC381' = @{ Name = 'SHARP DX-C381 PCL6'; Package = 'pcl6-mx1800' }
    'DXC400' = @{ Name = 'SHARP DX-C400 PCL6'; Package = 'pcl6-mx1800' }
    'DXC401' = @{ Name = 'SHARP DX-C401 PCL6'; Package = 'pcl6-mx1800' }
    'MX1800N' = @{ Name = 'SHARP MX-1800N PCL6'; Package = 'pcl6-mx1800' }
    'MX1810U' = @{ Name = 'SHARP MX-1810U PCL6'; Package = 'pcl6-m5071' }
    'MX2010U' = @{ Name = 'SHARP MX-2010U PCL6'; Package = 'pcl6-m5071' }
    'MX2300G' = @{ Name = 'SHARP MX-2300G PCL6'; Package = 'pcl6-mx1800' }
    'MX2300N' = @{ Name = 'SHARP MX-2300N PCL6'; Package = 'pcl6-mx1800' }
    'MX2301N' = @{ Name = 'SHARP MX-2301N PCL6'; Package = 'pcl6-mx1800' }
    'MX2310U' = @{ Name = 'SHARP MX-2310U PCL6'; Package = 'pcl6-m5071' }
    'MX2314N' = @{ Name = 'SHARP MX-2314N PCL6'; Package = 'pcl6-m5071' }
    'MX2314NR' = @{ Name = 'SHARP MX-2314NR PCL6'; Package = 'pcl6-m5071' }
    'MX2600G' = @{ Name = 'SHARP MX-2600G PCL6'; Package = 'pcl6-mx1800' }
    'MX2600N' = @{ Name = 'SHARP MX-2600N PCL6'; Package = 'pcl6-mx1800' }
    'MX2610N' = @{ Name = 'SHARP MX-2610N PCL6'; Package = 'pcl6-m5071' }
    'MX2614N' = @{ Name = 'SHARP MX-2614N PCL6'; Package = 'pcl6-m5071' }
    'MX2614NR' = @{ Name = 'SHARP MX-2614NR PCL6'; Package = 'pcl6-m5071' }
    'MX2615N' = @{ Name = 'SHARP MX-2615N PCL6'; Package = 'pcl6-m5071' }
    'MX2616N' = @{ Name = 'SHARP MX-2616N PCL6'; Package = 'pcl6-m5071' }
    'MX2630N' = @{ Name = 'SHARP MX-2630N PCL6'; Package = 'pcl6-m5070' }
    'MX2640N' = @{ Name = 'SHARP MX-2640N PCL6'; Package = 'pcl6-m5071' }
    'MX2651' = @{ Name = 'SHARP MX-2651 PCL6'; Package = 'pcl6-m5071' }
    'MX2700G' = @{ Name = 'SHARP MX-2700G PCL6'; Package = 'pcl6-mx1800' }
    'MX2700N' = @{ Name = 'SHARP MX-2700N PCL6'; Package = 'pcl6-mx1800' }
    'MX3050N' = @{ Name = 'SHARP MX-3050N PCL6'; Package = 'pcl6-m5070' }
    'MX3050V' = @{ Name = 'SHARP MX-3050V PCL6'; Package = 'pcl6-m5070' }
    'MX3051' = @{ Name = 'SHARP MX-3051 PCL6'; Package = 'pcl6-m5071' }
    'MX3060N' = @{ Name = 'SHARP MX-3060N PCL6'; Package = 'pcl6-m5070' }
    'MX3060V' = @{ Name = 'SHARP MX-3060V PCL6'; Package = 'pcl6-m5070' }
    'MX3061' = @{ Name = 'SHARP MX-3061 PCL6'; Package = 'pcl6-m5071' }
    'MX3061S' = @{ Name = 'SHARP MX-3061S PCL6'; Package = 'pcl6-m5071' }
    'MX3070N' = @{ Name = 'SHARP MX-3070N PCL6'; Package = 'pcl6-m5070' }
    'MX3070V' = @{ Name = 'SHARP MX-3070V PCL6'; Package = 'pcl6-m5070' }
    'MX3071' = @{ Name = 'SHARP MX-3071 PCL6'; Package = 'pcl6-m5071' }
    'MX3071S' = @{ Name = 'SHARP MX-3071S PCL6'; Package = 'pcl6-m5071' }
    'MX3100G' = @{ Name = 'SHARP MX-3100G PCL6'; Package = 'pcl6-mx1800' }
    'MX3100N' = @{ Name = 'SHARP MX-3100N PCL6'; Package = 'pcl6-mx1800' }
    'MX3110N' = @{ Name = 'SHARP MX-3110N PCL6'; Package = 'pcl6-m5071' }
    'MX3111U' = @{ Name = 'SHARP MX-3111U PCL6'; Package = 'pcl6-m5071' }
    'MX3114N' = @{ Name = 'SHARP MX-3114N PCL6'; Package = 'pcl6-m5071' }
    'MX3114NR' = @{ Name = 'SHARP MX-3114NR PCL6'; Package = 'pcl6-m5071' }
    'MX3115N' = @{ Name = 'SHARP MX-3115N PCL6'; Package = 'pcl6-m5071' }
    'MX3116N' = @{ Name = 'SHARP MX-3116N PCL6'; Package = 'pcl6-m5071' }
    'MX3140N' = @{ Name = 'SHARP MX-3140N PCL6'; Package = 'pcl6-m5071' }
    'MX3500N' = @{ Name = 'SHARP MX-3500N PCL6'; Package = 'pcl6-mx1800' }
    'MX3501N' = @{ Name = 'SHARP MX-3501N PCL6'; Package = 'pcl6-mx1800' }
    'MX3550N' = @{ Name = 'SHARP MX-3550N PCL6'; Package = 'pcl6-m5070' }
    'MX3550V' = @{ Name = 'SHARP MX-3550V PCL6'; Package = 'pcl6-m5070' }
    'MX3551' = @{ Name = 'SHARP MX-3551 PCL6'; Package = 'pcl6-m5071' }
    'MX3560N' = @{ Name = 'SHARP MX-3560N PCL6'; Package = 'pcl6-m5070' }
    'MX3560V' = @{ Name = 'SHARP MX-3560V PCL6'; Package = 'pcl6-m5070' }
    'MX3561' = @{ Name = 'SHARP MX-3561 PCL6'; Package = 'pcl6-m5071' }
    'MX3561S' = @{ Name = 'SHARP MX-3561S PCL6'; Package = 'pcl6-m5071' }
    'MX3570N' = @{ Name = 'SHARP MX-3570N PCL6'; Package = 'pcl6-m5070' }
    'MX3570V' = @{ Name = 'SHARP MX-3570V PCL6'; Package = 'pcl6-m5070' }
    'MX3571' = @{ Name = 'SHARP MX-3571 PCL6'; Package = 'pcl6-m5071' }
    'MX3571S' = @{ Name = 'SHARP MX-3571S PCL6'; Package = 'pcl6-m5071' }
    'MX3610N' = @{ Name = 'SHARP MX-3610N PCL6'; Package = 'pcl6-m5071' }
    'MX3640N' = @{ Name = 'SHARP MX-3640N PCL6'; Package = 'pcl6-m5071' }
    'MX4050N' = @{ Name = 'SHARP MX-4050N PCL6'; Package = 'pcl6-m5070' }
    'MX4050V' = @{ Name = 'SHARP MX-4050V PCL6'; Package = 'pcl6-m5070' }
    'MX4051' = @{ Name = 'SHARP MX-4051 PCL6'; Package = 'pcl6-m5071' }
    'MX4060N' = @{ Name = 'SHARP MX-4060N PCL6'; Package = 'pcl6-m5070' }
    'MX4060V' = @{ Name = 'SHARP MX-4060V PCL6'; Package = 'pcl6-m5070' }
    'MX4061' = @{ Name = 'SHARP MX-4061 PCL6'; Package = 'pcl6-m5071' }
    'MX4061S' = @{ Name = 'SHARP MX-4061S PCL6'; Package = 'pcl6-m5071' }
    'MX4070N' = @{ Name = 'SHARP MX-4070N PCL6'; Package = 'pcl6-m5070' }
    'MX4070V' = @{ Name = 'SHARP MX-4070V PCL6'; Package = 'pcl6-m5070' }
    'MX4071' = @{ Name = 'SHARP MX-4071 PCL6'; Package = 'pcl6-m5071' }
    'MX4071S' = @{ Name = 'SHARP MX-4071S PCL6'; Package = 'pcl6-m5071' }
    'MX4100N' = @{ Name = 'SHARP MX-4100N PCL6'; Package = 'pcl6-mx1800' }
    'MX4101N' = @{ Name = 'SHARP MX-4101N PCL6'; Package = 'pcl6-mx1800' }
    'MX4110N' = @{ Name = 'SHARP MX-4110N PCL6'; Package = 'pcl6-m5071' }
    'MX4111N' = @{ Name = 'SHARP MX-4111N PCL6'; Package = 'pcl6-m5071' }
    'MX4112N' = @{ Name = 'SHARP MX-4112N PCL6'; Package = 'pcl6-m5071' }
    'MX4140N' = @{ Name = 'SHARP MX-4140N PCL6'; Package = 'pcl6-m5071' }
    'MX4141N' = @{ Name = 'SHARP MX-4141N PCL6'; Package = 'pcl6-m5071' }
    'MX4500N' = @{ Name = 'SHARP MX-4500N PCL6'; Package = 'pcl6-mx1800' }
    'MX4501N' = @{ Name = 'SHARP MX-4501N PCL6'; Package = 'pcl6-mx1800' }
    'MX5000N' = @{ Name = 'SHARP MX-5000N PCL6'; Package = 'pcl6-mx1800' }
    'MX5001N' = @{ Name = 'SHARP MX-5001N PCL6'; Package = 'pcl6-mx1800' }
    'MX5050N' = @{ Name = 'SHARP MX-5050N PCL6'; Package = 'pcl6-m5070' }
    'MX5050V' = @{ Name = 'SHARP MX-5050V PCL6'; Package = 'pcl6-m5070' }
    'MX5051' = @{ Name = 'SHARP MX-5051 PCL6'; Package = 'pcl6-m5071' }
    'MX5070N' = @{ Name = 'SHARP MX-5070N PCL6'; Package = 'pcl6-m5070' }
    'MX5070V' = @{ Name = 'SHARP MX-5070V PCL6'; Package = 'pcl6-m5070' }
    'MX5071' = @{ Name = 'SHARP MX-5071 PCL6'; Package = 'pcl6-m5071' }
    'MX5071S' = @{ Name = 'SHARP MX-5071S PCL6'; Package = 'pcl6-m5071' }
    'MX5110N' = @{ Name = 'SHARP MX-5110N PCL6'; Package = 'pcl6-m5071' }
    'MX5111N' = @{ Name = 'SHARP MX-5111N PCL6'; Package = 'pcl6-m5071' }
    'MX5112N' = @{ Name = 'SHARP MX-5112N PCL6'; Package = 'pcl6-m5071' }
    'MX5140N' = @{ Name = 'SHARP MX-5140N PCL6'; Package = 'pcl6-m5071' }
    'MX5141N' = @{ Name = 'SHARP MX-5141N PCL6'; Package = 'pcl6-m5071' }
    'MX5500N' = @{ Name = 'SHARP MX-5500N PCL6'; Package = 'pcl6-mx1800' }
    'MX6050N' = @{ Name = 'SHARP MX-6050N PCL6'; Package = 'pcl6-m5070' }
    'MX6050V' = @{ Name = 'SHARP MX-6050V PCL6'; Package = 'pcl6-m5070' }
    'MX6051' = @{ Name = 'SHARP MX-6051 PCL6'; Package = 'pcl6-m5071' }
    'MX6070N' = @{ Name = 'SHARP MX-6070N PCL6'; Package = 'pcl6-m5070' }
    'MX6070V' = @{ Name = 'SHARP MX-6070V PCL6'; Package = 'pcl6-m5070' }
    'MX6071' = @{ Name = 'SHARP MX-6071 PCL6'; Package = 'pcl6-m5071' }
    'MX6071S' = @{ Name = 'SHARP MX-6071S PCL6'; Package = 'pcl6-m5071' }
    'MX6200N' = @{ Name = 'SHARP MX-6200N PCL6'; Package = 'pcl6-mx1800' }
    'MX6201N' = @{ Name = 'SHARP MX-6201N PCL6'; Package = 'pcl6-mx1800' }
    'MX6580N' = @{ Name = 'SHARP MX-6580N PCL6'; Package = 'pcl6-m5070' }
    'MX7000N' = @{ Name = 'SHARP MX-7000N PCL6'; Package = 'pcl6-mx1800' }
    'MX7001N' = @{ Name = 'SHARP MX-7001N PCL6'; Package = 'pcl6-mx1800' }
    'MX7081' = @{ Name = 'SHARP MX-7081 PCL6'; Package = 'pcl6-m5071' }
    'MX7090N' = @{ Name = 'SHARP MX-7090N PCL6'; Package = 'pcl6-m5070' }
    'MX7090NBM' = @{ Name = 'SHARP MX-7090N(BM) PCL6'; Package = 'pcl6-m5070' }
    'MX7580N' = @{ Name = 'SHARP MX-7580N PCL6'; Package = 'pcl6-m5070' }
    'MX8081' = @{ Name = 'SHARP MX-8081 PCL6'; Package = 'pcl6-m5071' }
    'MX8090N' = @{ Name = 'SHARP MX-8090N PCL6'; Package = 'pcl6-m5070' }
    'MX8090NBM' = @{ Name = 'SHARP MX-8090N(BM) PCL6'; Package = 'pcl6-m5070' }
    'MXB350' = @{ Name = 'SHARP MX-B350 PCL6'; Package = 'pcl6-m5070' }
    'MXB350F' = @{ Name = 'SHARP MX-B350F PCL6'; Package = 'pcl6-m5070' }
    'MXB350P' = @{ Name = 'SHARP MX-B350P PCL6'; Package = 'pcl6-m5070' }
    'MXB350W' = @{ Name = 'SHARP MX-B350W PCL6'; Package = 'pcl6-m5070' }
    'MXB351P' = @{ Name = 'SHARP MX-B351P PCL6'; Package = 'pcl6-m5070' }
    'MXB355W' = @{ Name = 'SHARP MX-B355W PCL6'; Package = 'pcl6-m5070' }
    'MXB356W' = @{ Name = 'SHARP MX-B356W PCL6'; Package = 'pcl6-m5071' }
    'MXB356WH' = @{ Name = 'SHARP MX-B356WH PCL6'; Package = 'pcl6-m5071' }
    'MXB376W' = @{ Name = 'SHARP MX-B376W PCL6'; Package = 'pcl6-m5071' }
    'MXB376WH' = @{ Name = 'SHARP MX-B376WH PCL6'; Package = 'pcl6-m5071' }
    'MXB380P' = @{ Name = 'SHARP MX-B380P PCL6'; Package = 'pcl6-m452' }
    'MXB381' = @{ Name = 'SHARP MX-B381 PCL6'; Package = 'pcl6-m452' }
    'MXB382' = @{ Name = 'SHARP MX-B382 PCL6'; Package = 'pcl6-m452' }
    'MXB382P' = @{ Name = 'SHARP MX-B382P PCL6'; Package = 'pcl6-m452' }
    'MXB382SC' = @{ Name = 'SHARP MX-B382SC PCL6'; Package = 'pcl6-m452' }
    'MXB400P' = @{ Name = 'SHARP MX-B400P PCL6'; Package = 'pcl6-m452' }
    'MXB401' = @{ Name = 'SHARP MX-B401 PCL6'; Package = 'pcl6-m452' }
    'MXB402' = @{ Name = 'SHARP MX-B402 PCL6'; Package = 'pcl6-m452' }
    'MXB402SC' = @{ Name = 'SHARP MX-B402SC PCL6'; Package = 'pcl6-m452' }
    'MXB450' = @{ Name = 'SHARP MX-B450 PCL6'; Package = 'pcl6-m5070' }
    'MXB450F' = @{ Name = 'SHARP MX-B450F PCL6'; Package = 'pcl6-m5070' }
    'MXB450P' = @{ Name = 'SHARP MX-B450P PCL6'; Package = 'pcl6-m5070' }
    'MXB450W' = @{ Name = 'SHARP MX-B450W PCL6'; Package = 'pcl6-m5070' }
    'MXB451P' = @{ Name = 'SHARP MX-B451P PCL6'; Package = 'pcl6-m5070' }
    'MXB455W' = @{ Name = 'SHARP MX-B455W PCL6'; Package = 'pcl6-m5070' }
    'MXB456W' = @{ Name = 'SHARP MX-B456W PCL6'; Package = 'pcl6-m5071' }
    'MXB456WH' = @{ Name = 'SHARP MX-B456WH PCL6'; Package = 'pcl6-m5071' }
    'MXB476W' = @{ Name = 'SHARP MX-B476W PCL6'; Package = 'pcl6-m5071' }
    'MXB476WH' = @{ Name = 'SHARP MX-B476WH PCL6'; Package = 'pcl6-m5071' }
    'MXC303' = @{ Name = 'SHARP MX-C303 PCL6'; Package = 'pcl6-m5071' }
    'MXC303W' = @{ Name = 'SHARP MX-C303W PCL6'; Package = 'pcl6-m5071' }
    'MXC303WH' = @{ Name = 'SHARP MX-C303WH PCL6'; Package = 'pcl6-m5071' }
    'MXC304' = @{ Name = 'SHARP MX-C304 PCL6'; Package = 'pcl6-m5071' }
    'MXC304W' = @{ Name = 'SHARP MX-C304W PCL6'; Package = 'pcl6-m5071' }
    'MXC304WH' = @{ Name = 'SHARP MX-C304WH PCL6'; Package = 'pcl6-m5071' }
    'MXC310' = @{ Name = 'SHARP MX-C310 PCL6'; Package = 'pcl6-mx1800' }
    'MXC311' = @{ Name = 'SHARP MX-C311 PCL6'; Package = 'pcl6-mx1800' }
    'MXC380' = @{ Name = 'SHARP MX-C380 PCL6'; Package = 'pcl6-mx1800' }
    'MXC381' = @{ Name = 'SHARP MX-C381 PCL6'; Package = 'pcl6-mx1800' }
    'MXC400' = @{ Name = 'SHARP MX-C400 PCL6'; Package = 'pcl6-mx1800' }
    'MXC401' = @{ Name = 'SHARP MX-C401 PCL6'; Package = 'pcl6-mx1800' }
    'MXM1056' = @{ Name = 'SHARP MX-M1056 PCL6'; Package = 'pcl6-m5071' }
    'MXM1056BM' = @{ Name = 'SHARP MX-M1056(BM) PCL6'; Package = 'pcl6-m5071' }
    'MXM1206' = @{ Name = 'SHARP MX-M1206 PCL6'; Package = 'pcl6-m5071' }
    'MXM1206BM' = @{ Name = 'SHARP MX-M1206(BM) PCL6'; Package = 'pcl6-m5071' }
    'MXM260FG' = @{ Name = 'SHARP MX-M260FG'; Package = 'gdi-m260' }
    'MXM2630' = @{ Name = 'SHARP MX-M2630 PCL6'; Package = 'pcl6-m5070' }
    'MXM264N' = @{ Name = 'SHARP MX-M264N PCL6'; Package = 'pcl6-m5071' }
    'MXM264NR' = @{ Name = 'SHARP MX-M264NR PCL6'; Package = 'pcl6-m5071' }
    'MXM264NV' = @{ Name = 'SHARP MX-M264NV PCL6'; Package = 'pcl6-m5071' }
    'MXM264U' = @{ Name = 'SHARP MX-M264U PCL6'; Package = 'pcl6-m5071' }
    'MXM2651' = @{ Name = 'SHARP MX-M2651 PCL6'; Package = 'pcl6-m5071' }
    'MXM265N' = @{ Name = 'SHARP MX-M265N PCL6'; Package = 'pcl6-m266' }
    'MXM265U' = @{ Name = 'SHARP MX-M265U PCL6'; Package = 'pcl6-m266' }
    'MXM266N' = @{ Name = 'SHARP MX-M266N PCL6'; Package = 'pcl6-m266' }
    'MXM282N' = @{ Name = 'SHARP MX-M282N PCL6'; Package = 'pcl6-m452' }
    'MXM283N' = @{ Name = 'SHARP MX-M283N PCL6'; Package = 'pcl6-m452' }
    'MXM3050' = @{ Name = 'SHARP MX-M3050 PCL6'; Package = 'pcl6-m5070' }
    'MXM3051' = @{ Name = 'SHARP MX-M3051 PCL6'; Package = 'pcl6-m5071' }
    'MXM3070' = @{ Name = 'SHARP MX-M3070 PCL6'; Package = 'pcl6-m5070' }
    'MXM3071' = @{ Name = 'SHARP MX-M3071 PCL6'; Package = 'pcl6-m5071' }
    'MXM3071S' = @{ Name = 'SHARP MX-M3071S PCL6'; Package = 'pcl6-m5071' }
    'MXM310FG' = @{ Name = 'SHARP MX-M310FG'; Package = 'gdi-m260' }
    'MXM314N' = @{ Name = 'SHARP MX-M314N PCL6'; Package = 'pcl6-m5071' }
    'MXM314NR' = @{ Name = 'SHARP MX-M314NR PCL6'; Package = 'pcl6-m5071' }
    'MXM314NV' = @{ Name = 'SHARP MX-M314NV PCL6'; Package = 'pcl6-m5071' }
    'MXM314U' = @{ Name = 'SHARP MX-M314U PCL6'; Package = 'pcl6-m5071' }
    'MXM315N' = @{ Name = 'SHARP MX-M315N PCL6'; Package = 'pcl6-m266' }
    'MXM315U' = @{ Name = 'SHARP MX-M315U PCL6'; Package = 'pcl6-m266' }
    'MXM316N' = @{ Name = 'SHARP MX-M316N PCL6'; Package = 'pcl6-m266' }
    'MXM350' = @{ Name = 'SHARP MX-M350 SPDL2_T1'; Package = 'spdl-ar' }
    'MXM350F' = @{ Name = 'SHARP MX-M350F SPDL2_T1'; Package = 'spdl-ar' }
    'MXM350N' = @{ Name = 'SHARP MX-M350N SPDL2_T1'; Package = 'spdl-ar' }
    'MXM354N' = @{ Name = 'SHARP MX-M354N PCL6'; Package = 'pcl6-m5071' }
    'MXM354NR' = @{ Name = 'SHARP MX-M354NR PCL6'; Package = 'pcl6-m5071' }
    'MXM354U' = @{ Name = 'SHARP MX-M354U PCL6'; Package = 'pcl6-m5071' }
    'MXM3550' = @{ Name = 'SHARP MX-M3550 PCL6'; Package = 'pcl6-m5070' }
    'MXM3551' = @{ Name = 'SHARP MX-M3551 PCL6'; Package = 'pcl6-m5071' }
    'MXM356N' = @{ Name = 'SHARP MX-M356N PCL6'; Package = 'pcl6-m266' }
    'MXM356U' = @{ Name = 'SHARP MX-M356U PCL6'; Package = 'pcl6-m266' }
    'MXM3570' = @{ Name = 'SHARP MX-M3570 PCL6'; Package = 'pcl6-m5070' }
    'MXM3571' = @{ Name = 'SHARP MX-M3571 PCL6'; Package = 'pcl6-m5071' }
    'MXM3571S' = @{ Name = 'SHARP MX-M3571S PCL6'; Package = 'pcl6-m5071' }
    'MXM362N' = @{ Name = 'SHARP MX-M362N PCL6'; Package = 'pcl6-m452' }
    'MXM363N' = @{ Name = 'SHARP MX-M363N PCL6'; Package = 'pcl6-m452' }
    'MXM363U' = @{ Name = 'SHARP MX-M363U PCL6'; Package = 'pcl6-m452' }
    'MXM364N' = @{ Name = 'SHARP MX-M364N PCL6'; Package = 'pcl6-m5071' }
    'MXM365N' = @{ Name = 'SHARP MX-M365N PCL6'; Package = 'pcl6-m5071' }
    'MXM4050' = @{ Name = 'SHARP MX-M4050 PCL6'; Package = 'pcl6-m5070' }
    'MXM4051' = @{ Name = 'SHARP MX-M4051 PCL6'; Package = 'pcl6-m5071' }
    'MXM4070' = @{ Name = 'SHARP MX-M4070 PCL6'; Package = 'pcl6-m5070' }
    'MXM4071' = @{ Name = 'SHARP MX-M4071 PCL6'; Package = 'pcl6-m5071' }
    'MXM4071S' = @{ Name = 'SHARP MX-M4071S PCL6'; Package = 'pcl6-m5071' }
    'MXM450' = @{ Name = 'SHARP MX-M450 SPDL2_T1'; Package = 'spdl-ar' }
    'MXM450F' = @{ Name = 'SHARP MX-M450F SPDL2_T1'; Package = 'spdl-ar' }
    'MXM450N' = @{ Name = 'SHARP MX-M450N SPDL2_T1'; Package = 'spdl-ar' }
    'MXM452N' = @{ Name = 'SHARP MX-M452N PCL6'; Package = 'pcl6-m452' }
    'MXM453N' = @{ Name = 'SHARP MX-M453N PCL6'; Package = 'pcl6-m452' }
    'MXM453U' = @{ Name = 'SHARP MX-M453U PCL6'; Package = 'pcl6-m452' }
    'MXM464N' = @{ Name = 'SHARP MX-M464N PCL6'; Package = 'pcl6-m5071' }
    'MXM465N' = @{ Name = 'SHARP MX-M465N PCL6'; Package = 'pcl6-m5071' }
    'MXM502N' = @{ Name = 'SHARP MX-M502N PCL6'; Package = 'pcl6-m452' }
    'MXM503N' = @{ Name = 'SHARP MX-M503N PCL6'; Package = 'pcl6-m452' }
    'MXM503U' = @{ Name = 'SHARP MX-M503U PCL6'; Package = 'pcl6-m452' }
    'MXM5050' = @{ Name = 'SHARP MX-M5050 PCL6'; Package = 'pcl6-m5070' }
    'MXM5051' = @{ Name = 'SHARP MX-M5051 PCL6'; Package = 'pcl6-m5071' }
    'MXM5070' = @{ Name = 'SHARP MX-M5070 PCL6'; Package = 'pcl6-m5070' }
    'MXM5071' = @{ Name = 'SHARP MX-M5071 PCL6'; Package = 'pcl6-m5071' }
    'MXM5071S' = @{ Name = 'SHARP MX-M5071S PCL6'; Package = 'pcl6-m5071' }
    'MXM550' = @{ Name = 'SHARP MX-M550 SPDL2_T1'; Package = 'spdl-ar' }
    'MXM564N' = @{ Name = 'SHARP MX-M564N PCL6'; Package = 'pcl6-m5071' }
    'MXM565N' = @{ Name = 'SHARP MX-M565N PCL6'; Package = 'pcl6-m5071' }
    'MXM6050' = @{ Name = 'SHARP MX-M6050 PCL6'; Package = 'pcl6-m5070' }
    'MXM6051' = @{ Name = 'SHARP MX-M6051 PCL6'; Package = 'pcl6-m5071' }
    'MXM6070' = @{ Name = 'SHARP MX-M6070 PCL6'; Package = 'pcl6-m5070' }
    'MXM6071' = @{ Name = 'SHARP MX-M6071 PCL6'; Package = 'pcl6-m5071' }
    'MXM6071S' = @{ Name = 'SHARP MX-M6071S PCL6'; Package = 'pcl6-m5071' }
    'MXM620' = @{ Name = 'SHARP MX-M620 SPDL2_T1'; Package = 'spdl-ar' }
    'MXM623N' = @{ Name = 'SHARP MX-M623N PCL6'; Package = 'pcl6-m452' }
    'MXM623U' = @{ Name = 'SHARP MX-M623U PCL6'; Package = 'pcl6-m452' }
    'MXM6570' = @{ Name = 'SHARP MX-M6570 PCL6'; Package = 'pcl6-m5070' }
    'MXM700' = @{ Name = 'SHARP MX-M700 SPDL2_T1'; Package = 'spdl-ar' }
    'MXM753N' = @{ Name = 'SHARP MX-M753N PCL6'; Package = 'pcl6-m452' }
    'MXM753U' = @{ Name = 'SHARP MX-M753U PCL6'; Package = 'pcl6-m452' }
    'MXM7570' = @{ Name = 'SHARP MX-M7570 PCL6'; Package = 'pcl6-m5070' }
    'MXM905' = @{ Name = 'SHARP MX-M905 PCL6'; Package = 'pcl6-m5070' }
}

function Get-SharpMatchToken([string]$DriverName) {
    if ([string]::IsNullOrWhiteSpace($DriverName)) { return '' }
    $t = $DriverName.ToUpperInvariant()
    $t = [regex]::Replace($t, '^SHARP\s+', '')
    $t = [regex]::Replace($t, '\s+PCL\s*6\s*$', '')
    $t = [regex]::Replace($t, '\s+SPDL2_T1\s*$', '')
    $t = [regex]::Replace($t, '\s+T1\s*$', '')
    return ([regex]::Replace($t, '\s+', ' ')).Trim()
}

function Test-SharpTokenInText([string]$Text, [string]$Token) {
    if ([string]::IsNullOrWhiteSpace($Token)) { return $false }
    $parts = @($Token -split '\s+' | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
    if ($parts.Count -eq 0) { return $false }
    $body = ($parts | ForEach-Object { [regex]::Escape($_) }) -join '\s*'
    return [regex]::IsMatch($Text, '(?<![A-Z0-9])' + $body + '(?![A-Z0-9])')
}

function Find-SharpModelDriver {
    param([string]$ModelText)
    if ([string]::IsNullOrWhiteSpace($ModelText)) { return $null }
    $text = $ModelText.ToUpperInvariant()
    $best = $null
    $bestKey = $null
    $bestLen = -1
    foreach ($key in @($script:SharpModelDrivers.Keys)) {
        $hit = $script:SharpModelDrivers[$key]
        $token = [string]$hit['Match']
        if ([string]::IsNullOrWhiteSpace($token)) { $token = Get-SharpMatchToken ([string]$hit.Name) }
        if (-not (Test-SharpTokenInText $text $token)) { continue }
        $len = ($token -replace '\s', '').Length
        if ($len -gt $bestLen) {
            $best = $hit
            $bestKey = [string]$key
            $bestLen = $len
        }
    }
    if (-not $best) { return $null }
    $pkgId = [string]$best.Package
    if (-not $script:SharpModelPackages.ContainsKey($pkgId)) { return $null }
    return [pscustomobject]@{
        Key = $bestKey
        DriverName = [string]$best.Name
        PackageId = $pkgId
        Package = $script:SharpModelPackages[$pkgId]
    }
}

function Get-SharpModelKey([string]$ModelText) {
    $hit = Find-SharpModelDriver $ModelText
    if (-not $hit) { return $null }
    return [string]$hit.Key
}

function Find-SharpModelInfFile {
    param([Parameter(Mandatory = $true)][string]$Root, [Parameter(Mandatory = $true)][string]$DriverName)
    $needle = '"' + $DriverName + '"'
    $hits = New-Object System.Collections.ArrayList
    Get-ChildItem -LiteralPath $Root -Filter '*.inf' -Recurse -ErrorAction SilentlyContinue | ForEach-Object {
        $bytes = $null
        try { $bytes = [IO.File]::ReadAllBytes($_.FullName) } catch { return }
        $text = $null
        if ($bytes.Length -ge 2 -and $bytes[0] -eq 255 -and $bytes[1] -eq 254) {
            $text = [Text.Encoding]::Unicode.GetString($bytes)
        } else {
            $text = [Text.Encoding]::ASCII.GetString($bytes)
        }
        if ($text.Contains($needle)) { [void]$hits.Add($_.FullName) }
    }
    if ($hits.Count -eq 0) { return $null }
    $pcl = @($hits | Where-Object { [IO.Path]::GetFileName($_ ) -match '(?i)pcl|emcht|menu' })
    if ($pcl.Count -gt 0) { return [string]$pcl[0] }
    return [string]$hits[0]
}

function Save-SharpModelPackage {
    param([Parameter(Mandatory = $true)][string]$PackageId)
    if (-not $script:SharpModelPackages.ContainsKey($PackageId)) { throw ('沒有這個 Sharp 驅動包：' + $PackageId) }
    $pkg = $script:SharpModelPackages[$PackageId]
    $file = [string]$pkg.File
    $expect = ([string]$pkg.Sha256).ToLowerInvariant()
    $root = $env:USERPROFILE
    if ([string]::IsNullOrWhiteSpace($root)) { $root = [IO.Path]::GetTempPath() }
    $dir = Join-Path $root 'Downloads\lanyen-drivers\Sharp'
    if (-not (Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    $dest = Join-Path $dir $file
    $copied = $false
    if (Get-Command Resolve-FlgOfflinePath -ErrorAction SilentlyContinue) {
        foreach ($rel in @((Join-Path 'drivers\packages' $file), (Join-Path 'drivers\packages\sharp' $file))) {
            $local = Resolve-FlgOfflinePath $rel
            if ($local) {
                Copy-Item -LiteralPath $local -Destination $dest -Force
                if (Get-Command Write-Ok -ErrorAction SilentlyContinue) { Write-Ok ('離線模式：使用本機驅動包 ' + $file) }
                $copied = $true
                break
            }
        }
    }
    $have = $false
    if ((Test-Path -LiteralPath $dest) -and (Get-Item -LiteralPath $dest).Length -gt 200KB) {
        $actual = (Get-FileHash -LiteralPath $dest -Algorithm SHA256).Hash.ToLowerInvariant()
        if ($actual -eq $expect) { $have = $true }
        elseif ($copied) { throw ('離線驅動包 SHA256 不符：' + $file) }
    }
    if (-not $have) {
        $offline = $false
        if (Get-Command Test-FlgOffline -ErrorAction SilentlyContinue) { $offline = [bool](Test-FlgOffline) }
        if ($offline) {
            $net = $false
            if (Get-Command Test-FlgNetworkAvailable -ErrorAction SilentlyContinue) { $net = [bool](Test-FlgNetworkAvailable) }
            if (-not $net) { throw ('離線版找不到 Sharp 驅動包：' + $file) }
            if (Get-Command Write-WarnMsg -ErrorAction SilentlyContinue) { Write-WarnMsg '離線模式找不到本機驅動包，改從網路下載…' }
        }
        if (Get-Command Write-Info -ErrorAction SilentlyContinue) { Write-Info ('下載 Sharp 機型驅動：' + $file) }
        Invoke-WebRequest -Uri ([string]$pkg.Url) -OutFile $dest -UseBasicParsing
        if (-not (Test-Path -LiteralPath $dest) -or (Get-Item -LiteralPath $dest).Length -lt 200KB) {
            throw ('Sharp 驅動包下載失敗：' + $file)
        }
        $actual2 = (Get-FileHash -LiteralPath $dest -Algorithm SHA256).Hash.ToLowerInvariant()
        if ($actual2 -ne $expect) { throw ('Sharp 驅動包 SHA256 不符：期望 ' + $expect + ' 實際 ' + $actual2) }
        if (Get-Command Write-Ok -ErrorAction SilentlyContinue) { Write-Ok 'SHA256 正確' }
    }
    return $dest
}

function Enable-SharpSnmpPort([string]$PortName) {
    try {
        $esc = $PortName.Replace("'", "''")
        $wmiPort = Get-CimInstance -ClassName Win32_TCPIPPrinterPort -Filter "Name='$esc'"
        if (-not $wmiPort) { return }
        $props = @{ SNMPEnabled = $true; SNMPCommunity = 'public' }
        if ($wmiPort.PSObject.Properties.Name -contains 'SNMPDevIndex') { $props.SNMPDevIndex = 1 }
        Set-CimInstance -InputObject $wmiPort -Property $props
        if (Get-Command Write-Ok -ErrorAction SilentlyContinue) { Write-Ok '已開啟連接埠 SNMP（public）' }
    } catch {
        if (Get-Command Write-WarnMsg -ErrorAction SilentlyContinue) {
            Write-WarnMsg ('開啟連接埠 SNMP 失敗：' + $_.Exception.Message)
        }
    }
}

function Install-SharpModelDriverPackage {
    param(
        [Parameter(Mandatory = $true)][string]$DriverName,
        [Parameter(Mandatory = $true)][string]$PackageId,
        [Parameter(Mandatory = $true)][string]$Ip,
        [Parameter(Mandatory = $true)][string]$PrinterName
    )
    $zipPath = Save-SharpModelPackage -PackageId $PackageId
    $work = Join-Path $env:TEMP ('FLG-SharpModel-' + [Guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path $work -Force | Out-Null
    try {
        Write-Info '解開 Sharp 機型驅動…'
        Expand-Archive -LiteralPath $zipPath -DestinationPath $work -Force
        $inf = Find-SharpModelInfFile -Root $work -DriverName $DriverName
        if (-not $inf) { throw ('安裝檔裡找不到驅動：' + $DriverName) }
        Write-Ok ('INF：' + $inf)
        Write-Info '安裝驅動套件（pnputil）…'
        $pnp = & pnputil.exe /add-driver $inf /install 2>&1
        $pnp | ForEach-Object { Write-Host ('  ' + $_) }
        $pnpCode = $LASTEXITCODE
        $inStore = $false
        if (Get-Command Test-PrinterDriverInStore -ErrorAction SilentlyContinue) {
            $inStore = [bool](Test-PrinterDriverInStore $DriverName)
        } else {
            $inStore = [bool](Get-PrinterDriver -Name $DriverName -ErrorAction SilentlyContinue)
        }
        if ($pnpCode -ne 0 -and $null -ne $pnpCode -and -not $inStore) {
            throw ('pnputil 安裝驅動失敗（結束碼 ' + $pnpCode + '）。')
        }
        if (-not (Get-PrinterDriver -Name $DriverName -ErrorAction SilentlyContinue)) {
            Add-PrinterDriver -Name $DriverName -ErrorAction Stop
        } else {
            Write-Ok '驅動已存在，略過 Add-PrinterDriver'
        }
        $portName = 'IP_' + $Ip
        if (-not (Get-PrinterPort -Name $portName -ErrorAction SilentlyContinue)) {
            Add-PrinterPort -Name $portName -PrinterHostAddress $Ip -ErrorAction Stop
        }
        Enable-SharpSnmpPort $portName
        $prev = Get-Printer -Name $PrinterName -ErrorAction SilentlyContinue
        if ($prev) {
            Write-WarnMsg '同名印表機已存在，將移除後重建…'
            Remove-Printer -Name $PrinterName -ErrorAction Stop
        }
        Add-Printer -Name $PrinterName -DriverName $DriverName -PortName $portName -ErrorAction Stop
        try {
            Set-PrintConfiguration -PrinterName $PrinterName -Color $false -DuplexingMode OneSided -ErrorAction Stop
            Write-Ok '已設定預設：黑白、單面'
        } catch { Write-WarnMsg ('設定黑白單面失敗：' + $_.Exception.Message) }
        $esc = $PrinterName.Replace("'", "''")
        try { Set-ItemProperty -Path 'HKCU:\Software\Microsoft\Windows NT\CurrentVersion\Windows' -Name 'LegacyDefaultPrinterMode' -Value 1 -Type DWord -ErrorAction Stop } catch {}
        try {
            $printer = Get-CimInstance -ClassName Win32_Printer -Filter ("Name='$esc'")
            Invoke-CimMethod -InputObject $printer -MethodName SetDefaultPrinter | Out-Null
            Write-Ok '已設為預設印表機'
        } catch {
            try { (New-Object -ComObject WScript.Network).SetDefaultPrinter($PrinterName) | Out-Null; Write-Ok '已設為預設印表機' }
            catch { Write-WarnMsg ('設預設失敗：' + $_.Exception.Message) }
        }
        Start-Sleep -Seconds 2
        try {
            $printer = Get-CimInstance -ClassName Win32_Printer -Filter ("Name='$esc'")
            $null = Invoke-CimMethod -InputObject $printer -MethodName PrintTestPage
            Write-Ok '已送出測試頁'
        } catch {
            try { Start-Process -FilePath 'rundll32.exe' -ArgumentList ('printui.dll,PrintUIEntry /k /n "' + $PrinterName + '"') -Wait; Write-Ok '已送出測試頁' }
            catch { Write-WarnMsg ('測試頁失敗：' + $_.Exception.Message) }
        }
        Write-Ok 'Sharp 機型驅動安裝完成。'
        Write-Host ('  驅動：' + $DriverName) -ForegroundColor Green
        Write-Host ('  印表機：' + $PrinterName) -ForegroundColor Green
        Write-Host ('  連接埠：' + $portName + ' → ' + $Ip + '（SNMP public）') -ForegroundColor Green
    } finally {
        if (Test-Path -LiteralPath $work) {
            Remove-Item -LiteralPath $work -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}

# openwrt_mesh_configurate


## English
Mesh network configure on boot.

- Automatically download, install, configurate toolchain to build ad-hoc module firmware
- Tested device : GL-MT300NV2(default), Omega Onion2P, GL-AR300M16-Ext(Beta)
- Execute `main_launcher.sh` to do all procedure. If something's wrong, you can use each step's script manually. 
- Procedure(Manual) : `clone_openwrt_22035_github.sh` > `copy_config.sh` > `customize_mesh.sh` > `build_firmware.sh`

## Korean
ad-hoc 모듈 펌웨어를 다운로드, 설치, 구성하기 위한 자동화 스크립트입니다.

- 자동으로 openwrt 다운로드, mesh 디바이스 설정을 위한 변동사항 적용을 진행합니다.
- Tested Device : GL-MT300Nv2(기본), Omega Onion2P, GL-AR300M16-Ext(Beta)
- `main_launcher.sh` 를 실행하면 자동으로 진행됩니다. 잘못될 경우, 수동으로 일부 과정을 단계적으로 실행할 수 있습니다.
- 수동 순서 : `clone_openwrt_22035_github.sh` > `copy_config.sh` > `customize_mesh.sh` > `build_firmware.sh`

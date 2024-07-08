{ stdenv
, lib
, requireFile
, unzip
, makeWrapper, autoPatchelfHook
, jre
, zlib
, libxml2
, nss
, nspr
, openssl
, glib
, libGL
, gtk2-x11
, self'lib
, mkFlexSetupHook
}: {
  airVersion
, airSdk
}: let
  inherit (stdenv) hostPlatform;
  runtimeDir = self'lib.airRuntimeDir { inherit airVersion hostPlatform; };
  naipBin = if hostPlatform.system == "x86_64-linux" then "naip_linux64"
    else if hostPlatform.system == "aarch64-linux" then "naip_linux_arm64"
    else "naip";
in stdenv.mkDerivation (drv: let
  env = placeholder: {
    AIR_HOME = "${placeholder "out"}/${drv.sdkHome}";
    PLAYERGLOBAL_HOME = "${placeholder "out"}/${drv.sdkHome}/libs/player";
  };
  passthru = placeholder: env placeholder // {
    AIRGLOBAL_HOME = "${placeholder "out"}/${drv.sdkHome}";
    AIR_RUNTIME = "${placeholder "runtime"}/${drv.sdkHome}/runtimes/air/${drv.runtimeDir}";
    AIR_RUNTIME_PATH = "${placeholder "runtime"}/${drv.sdkHome}/runtimes/air/${drv.runtimeDir}/Adobe AIR/Versions/1.0";
  };
in {
  version = airVersion;
  pname = "harman-air-sdk" + lib.optionalString (airSdk == "harman-flex") "-flex";
  src = self'lib.airSrcFor { inherit airVersion airSdk hostPlatform requireFile; };
  sourceRoot = ".";

  nativeBuildInputs = [ unzip makeWrapper ]
  ++ lib.optional hostPlatform.isLinux autoPatchelfHook;
  buildInputs = [ jre ]
  ++ lib.optionals hostPlatform.isLinux [
    # required by naip
    zlib
    libxml2
    nss
    nspr
    openssl
    glib
    #libGL or libglvnd?
    gtk2-x11
  ];

  JAVA_HOME = jre.home;
  inherit (env placeholder) AIR_HOME;
  inherit (passthru placeholder) AIR_RUNTIME AIR_RUNTIME_PATH;
  inherit (self'lib) sdkHome;
  inherit jre;

  inherit runtimeDir naipBin;
  outputs = [ "out" "runtime" ];
  installPhase = ''
    runHook preInstall

    install -d $out/$sdkHome $out/bin
    mv ./* $out/$sdkHome/

    if [[ $naipBin != naip && -e $out/$sdkHome/lib/nai/bin/$naipBin ]]; then
      mv $out/$sdkHome/lib/nai/bin/$naipBin $out/$sdkHome/lib/nai/bin/naip
    fi
    rm -f $out/$sdkHome/lib/nai/bin/naip_*

    install -d $runtime/$sdkHome/runtimes/air
    cp -a $out/$sdkHome/runtimes/air/$runtimeDir $runtime/$sdkHome/runtimes/air/

    runHook postInstall
  '';

  dontAutoPatchelf = true;
  preFixup = let
    fixupPhase'linux = ''
      for airBin in "$AIR_RUNTIME_PATH/libCore.so" "$AIR_RUNTIME_PATH/Resources/"*.so.* "$AIR_RUNTIME_PATH/Resources/captiveentry"; do
        autoPatchelf $airBin
      done

      autoPatchelf $out/$sdkHome/lib/nai/bin/naip

      for airBin in $out/$sdkHome/bin/*; do
        if [[ ! -x $airBin || -d $airBin ]]; then
          continue
        fi
        makeWrapper $airBin $out/bin/$(basename "$airBin") \
          --set-default AIR_DISTRO debian \
          --set-default AIR_HOME "$AIR_HOME" \
          --set-default JAVA_HOME "$JAVA_HOME" \
          --suffix PATH : "$jre/bin"
      done
    '';
  in lib.optionalString hostPlatform.isLinux fixupPhase'linux;

  setupHook = mkFlexSetupHook drv.pname env;

  passthru = passthru (output: drv.finalPackage.${output});
})

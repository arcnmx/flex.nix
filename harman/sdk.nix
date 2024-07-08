{ stdenv
, lib
, requireFile
, unzip
, makeWrapper, autoPatchelfHook
, jre
, zlib
, libxml2
, libsecret
, nss
, nspr
, openssl
, glib
, libGL
, libglvnd
, gtk2-x11
, self'lib
, mkFlexSetupHook
, gdk-pixbuf
, fontconfig
, freetype
, pango
, xorg ? null
, libX11 ? xorg.libX11
, libXcursor ? xorg.libXcursor
, libXrender ? xorg.libXrender
}: {
  airVersion
, airSdk
}: let
  inherit (stdenv) hostPlatform;
  runtimeDir = self'lib.airRuntimeDir { inherit airVersion hostPlatform; };
  binSuffix = if hostPlatform.system == "x86_64-linux" then "_linux64"
    else if hostPlatform.system == "aarch64-linux" then "_linux_arm64"
    else "";
  naipBin = "naip${binSuffix}";
  runtimeExtensions = "FlashRuntimeExtensions${binSuffix}";
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
  runtimeDependencies = lib.optionals hostPlatform.isLinux [
    # required by naip
    zlib
    libxml2
    libsecret
    nss
    nspr
    openssl
    glib
    libglvnd # or libGL
    gtk2-x11
    # transitive
    gdk-pixbuf
    libX11
    libXcursor
    libXrender
    fontconfig
    freetype
    pango
  ];
  runtimeDependencyPaths = runtimeDependencies ++ lib.optionals hostPlatform.isLinux [ stdenv.cc.libc stdenv.cc.cc ];
in {
  version = airVersion;
  pname = "harman-air-sdk" + lib.optionalString (airSdk == "harman-flex") "-flex";
  src = self'lib.airSrcFor { inherit airVersion airSdk hostPlatform requireFile; };
  sourceRoot = ".";

  nativeBuildInputs = [ unzip makeWrapper ]
  ++ lib.optional hostPlatform.isLinux autoPatchelfHook;
  buildInputs = [ jre ]
  ++ lib.optionals hostPlatform.isLinux runtimeDependencies;

  JAVA_HOME = jre.home;
  inherit (env placeholder) AIR_HOME;
  inherit (self'lib) sdkHome;
  inherit jre;

  inherit runtimeDir naipBin runtimeExtensions;
  outputs = [ "out" "runtime" "runtimes" ];
  installPhase = ''
    runHook preInstall

    install -d $runtimes/$sdkHome
    mv runtimes $runtimes/$sdkHome

    install -d $AIR_HOME $out/bin
    mv ./* $AIR_HOME/

    if [[ ! -e $AIR_HOME/lib/nai/bin/$naipBin ]]; then
      naipBin=naip
    fi

    if [[ ! -e $AIR_HOME/lib/$runtimeExtensions.so ]]; then
      runtimeExtensions=FlashRuntimeExtensions
    fi

    install -d $AIR_HOME/runtimes/air $runtime/$sdkHome/runtimes/air
    cp -a $runtimes/$sdkHome/runtimes/air/$runtimeDir $runtime/$sdkHome/runtimes/air/
    cp -a $runtimes/$sdkHome/runtimes/air/$runtimeDir $AIR_HOME/runtimes/air/

    runHook postInstall
  '';

  runtimeDependencyPaths = lib.makeLibraryPath runtimeDependencyPaths;
  dontAutoPatchelf = true;
  preFixup = let
    fixupPhase'linux = ''
      if [[ $runtimeDir != linux ]]; then
        ln -s $runtimeDir $AIR_HOME/runtimes/air/linux
      fi

      autoPatchelf $AIR_HOME/lib/nai/bin/$naipBin
      #autoPatchelf $AIR_HOME/lib/$runtimeExtensions.so
      autoPatchelf -- $runtime

      for airBin in $AIR_HOME/bin/*; do
        if [[ ! -x $airBin || -d $airBin ]]; then
          continue
        fi
        makeWrapper $airBin $out/bin/$(basename "$airBin") \
          --set-default AIR_DISTRO debian \
          --set-default AIR_HOME "$AIR_HOME" \
          --set-default JAVA_HOME "$JAVA_HOME" \
          --suffix PATH : "$jre/bin"
      done

      mv $AIR_HOME/lib/nai/bin/{$naipBin,$naipBin-wrapped}
      makeWrapper $AIR_HOME/lib/nai/bin/$naipBin-wrapped $AIR_HOME/lib/nai/bin/$naipBin \
        --suffix LD_LIBRARY_PATH : "$runtimeDependencyPaths"
      substituteInPlace $AIR_HOME/lib/nai/bin/$naipBin \
        --replace "$AIR_HOME/lib/nai/bin" '$AIR_HOME/lib/nai/bin'
    '';
  in lib.optionalString hostPlatform.isLinux fixupPhase'linux;

  setupHook = mkFlexSetupHook drv.pname env;

  passthru = passthru (output: drv.finalPackage.${output});
})

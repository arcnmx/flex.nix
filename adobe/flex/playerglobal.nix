{ stdenvNoCC
, lib
, fetchurl
, mkFlexSetupHook
, self'lib
}: {
  version
, sha256
, url ? "https://fpdownload.macromedia.com/get/flashplayer/updaters/${lib.versions.major version}/${libraryName}"
, libraryName ? "playerglobal${lib.replaceStrings [ "." ] [ "_" ] (lib.versions.majorMinor version)}.swc"
, sdkHome ? self'lib.sdkHome
}: stdenvNoCC.mkDerivation (drv: let
  env = placeholder: {
    PLAYERGLOBAL_HOME = "${placeholder "out"}/${drv.sdkHome}/frameworks/libs/player";
  };
in {
  pname = "adobe-flash-player-playerglobal";
  inherit version;

  src = fetchurl {
    inherit url sha256;
  };

  sourceRoot = ".";
  inherit libraryName sdkHome;
  inherit (env placeholder) PLAYERGLOBAL_HOME;
  unpackPhase = ''
    runHook preUnpack

    cp $src $libraryName

    runHook postUnpack
  '';

  installPhase = ''
    runHook preInstall

    install -D $libraryName $PLAYERGLOBAL_HOME/$version/playerglobal.swc

    runHook postInstall
  '';

  setupHook = mkFlexSetupHook drv.pname env;

  passthru = env (output: drv.finalPackage.${output});
})

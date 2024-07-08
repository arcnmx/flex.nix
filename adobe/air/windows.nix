{
  stdenvNoCC
, fetchurl
, unzip
, mkFlexSetupHook
, self'lib
}: stdenvNoCC.mkDerivation (drv: let
  env = placeholder: {
    AIR_HOME = "${placeholder "out"}/${drv.sdkHome}";
  };
  env'air = placeholder: {
    AIR_HOME = "${placeholder "airglobal"}/${drv.sdkHome}";
  };
  passthru = placeholder: env placeholder // {
    AIRGLOBAL_HOME = (env'air placeholder).AIR_HOME;
  };
in {
  pname = "adobe-air-sdk-windows";
  version = "32.0";

  src = fetchurl {
    url = "https://airdownload.adobe.com/air/win/download/${drv.version}/AdobeAIRSDK.zip";
    sha256 = "sha256-G5+bZa+N44lfW9VUcPbfS8jz0QTINEzrlJf9iVVZp8E=";
  };
  sourceRoot = ".";
  nativeBuildInputs = [ unzip ];

  inherit (self'lib) sdkHome;
  inherit (passthru placeholder) AIR_HOME AIRGLOBAL_HOME;
  outputs = [ "out" "airglobal" ];
  installPhase = ''
    runHook preInstall

    install -d $AIR_HOME $out/bin
    mv ./* $AIR_HOME/

    for f in $(cd $AIR_HOME/bin; echo *.exe); do
      ln -s $AIR_HOME/bin/$f $out/bin/$f
    done

    install -D $AIR_HOME/frameworks/libs/air/airglobal.swc $AIRGLOBAL_HOME/frameworks/libs/air/airglobal.swc

    runHook postInstall
  '';

  setupHook = mkFlexSetupHook drv.pname env;
  setupHookAir = mkFlexSetupHook drv.pname env'air;
  postFixup = ''
    install -d $airglobal/nix-support
    substituteAll $setupHookAir $airglobal/nix-support/setup-hook
  '';

  passthru = passthru (output: drv.finalPackage.${output});
})

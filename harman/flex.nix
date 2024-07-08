{ stdenvNoCC
, lib
, apache-flex-sdk
, harman-air-sdk-flex
, makeWrapper
, lndir ? xorg'lndir, xorg'lndir ? null
, mkFlexSetupHook
, self'lib
}: let
  inherit (stdenvNoCC) hostPlatform;
in stdenvNoCC.mkDerivation (drv: let
  env = placeholder: {
    AIR_HOME = "${placeholder "out"}/${drv.sdkHome}";
    PLAYERGLOBAL_HOME = drv.harmanSdk.PLAYERGLOBAL_HOME;
  };
  passthru = placeholder: env placeholder // {
    FLEX_HOME = drv.flexSdk.FLEX_HOME;
  };
in {
  pname = "apache-air-harman-sdk";
  version = "${apache-flex-sdk.version}_${harman-air-sdk-flex.version}";
  dontUnpack = true;
  inherit (passthru placeholder) FLEX_HOME AIR_HOME;
  HARMAN_AIR_HOME = drv.harmanSdk.AIR_HOME;
  propagatedBuildInputs = [ drv.flexSdk ];
  buildInputs = [
    drv.harmanSdk
    drv.harmanSdk.jre
  ];

  inherit (self'lib) sdkHome;
  flexSdk = apache-flex-sdk;
  harmanSdk = harman-air-sdk-flex;
  inherit (drv.harmanSdk) jre JAVA_HOME;

  nativeBuildInputs = [ lndir ]
  ++ lib.optional hostPlatform.isLinux makeWrapper;

  installPhase = ''
    runHook preInstall

    install -d $AIR_HOME $out/bin
    lndir -silent $FLEX_HOME $AIR_HOME
    lndir -silent $HARMAN_AIR_HOME $AIR_HOME

    rm $AIR_HOME/lib/*.jar
    cp -af $FLEX_HOME/lib/*.jar $AIR_HOME/lib/
    cp -af $HARMAN_AIR_HOME/lib/*.jar $AIR_HOME/lib/

    rm $AIR_HOME/lib/nai/bin/*
    cp -af $HARMAN_AIR_HOME/lib/nai/bin/* $AIR_HOME/lib/nai/bin/

    runHook postInstall
  '';

  preFixup = let
    fixupPhase'linux = ''
      for sdkBin in $HARMAN_AIR_HOME/bin/*; do
        if [[ ! -x $sdkBin || -d $sdkBin ]]; then
          continue
        fi
        makeWrapper $AIR_HOME/bin/$(basename "$sdkBin") $out/bin/$(basename "$sdkBin") \
          --set-default AIR_HOME "$AIR_HOME" \
          --set-default AIR_DISTRO debian \
          --set-default JAVA_HOME "$JAVA_HOME" \
          --suffix PATH : "$jre/bin"
      done
    '';
  in lib.optionalString hostPlatform.isLinux fixupPhase'linux;

  setupHook = mkFlexSetupHook drv.pname env;

  passthru = passthru (output: drv.finalPackage.${output}) // {
    inherit apache-flex-sdk harman-air-sdk-flex;
  };
})

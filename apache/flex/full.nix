{ stdenvNoCC
, lib
, apache-flex-sdk
, adobe-flex-sdk-windows
, adobe-flex-sdk-fontkit-deps
, makeWrapper
, mkFlexSetupHook
, lndir ? xorg'lndir
, xorg'lndir ? null
, enableAdt ? false
, self'lib
}: let
  inherit (stdenvNoCC) hostPlatform;
in stdenvNoCC.mkDerivation (drv: let
  env = placeholder: {
    FLEX_HOME = "${placeholder "out"}/${drv.sdkHome}";
  };
in {
  pname = "apache-flex-sdk-full";
  inherit (apache-flex-sdk) version;
  dontUnpack = true;

  nativeBuildInputs = [
    lndir
  ] ++ lib.optional hostPlatform.isLinux makeWrapper;

  buildInputs = [
    drv.flexSdk
  ] ++ drv.flexOptionalDeps
  ++ lib.optional enableAdt adobe-flex-sdk-windows.adt;

  flexSdk = apache-flex-sdk;
  flexOptionalDepsSdkHome = adobe-flex-sdk-fontkit-deps.sdkHome; # adobe-flex-sdk-windows.sdkHome
  flexOptionalDeps = lib.toList adobe-flex-sdk-fontkit-deps
  # ++ adobe-flex-sdk-windows.optionalDeps;
  ++ lib.optional enableAdt adobe-flex-sdk-windows.adt;
  APACHE_FLEX_HOME = drv.flexSdk.FLEX_HOME;
  inherit (env placeholder) FLEX_HOME;
  inherit (self'lib) sdkHome;

  installPhase = ''
    runHook preInstall

    install -d $FLEX_HOME $out/bin
    lndir -silent $APACHE_FLEX_HOME $FLEX_HOME

    rm $FLEX_HOME/lib/*.jar
    cp -af $APACHE_FLEX_HOME/lib/*.jar $FLEX_HOME/lib/

    for sdkDep in $flexOptionalDeps; do
      lndir -silent $sdkDep/$flexOptionalDepsSdkHome $FLEX_HOME
    done

    runHook postInstall
  '';

  preFixup = let
    fixupPhase'linux = ''
      for sdkBin in $flexSdk/bin/*; do
        if [[ ! -x $sdkBin || -d $sdkBin ]]; then
          continue
        fi
        makeWrapper $sdkBin $out/bin/$(basename "$sdkBin") \
          --set-default FLEX_HOME "$FLEX_HOME"
      done
    '';
  in lib.optionalString hostPlatform.isLinux fixupPhase'linux;

  setupHook = mkFlexSetupHook drv.pname env;

  passthru = env (output: drv.finalPackage.${output});
})

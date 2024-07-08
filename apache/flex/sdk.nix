{ nixpkgs'apache-flex-sdk
, mkFlexSetupHook
, makeWrapper
, jre
, lib
, self'lib
}: let
  inherit (self'lib) sdkHome;
  inherit (apache-flex-sdk.stdenv) hostPlatform;
  apache-flex-sdk = nixpkgs'apache-flex-sdk.override {
    inherit jre;
  };
in nixpkgs'apache-flex-sdk.stdenv.mkDerivation (drv: let
  env = placeholder: {
    FLEX_HOME = "${placeholder "out"}/${drv.sdkHome}";
  };
in {
  inherit (nixpkgs'apache-flex-sdk) pname version src;
  nativeBuildInputs = lib.optional hostPlatform.isLinux makeWrapper;
  buildInputs = [ jre ];

  postPatch = ":";

  inherit sdkHome jre;
  inherit (env placeholder) FLEX_HOME;
  JAVA_HOME = jre.home;

  installPhase = let
    installPhase'windows = ''
      todo
    '';
    installPhase'linux = ''
      rm $out/$sdkHome/bin/*.bat
    '';
    installPhase = if hostPlatform.isWindows then installPhase'windows else installPhase'linux;
  in ''
    runHook preInstall

    install -d $out/$sdkHome $out/bin
    mv ./* $out/$sdkHome/
    ${installPhase}

    runHook postInstall
  '';

  preFixup = let
    fixupPhase'linux = ''
      for sdkBin in $out/$sdkHome/bin/*; do
        if [[ ! -x $sdkBin || -d $sdkBin ]]; then
          continue
        fi
        makeWrapper $sdkBin $out/bin/$(basename "$sdkBin") \
          --set-default FLEX_HOME "$FLEX_HOME" \
          --set-default JAVA_HOME "$JAVA_HOME" \
          --suffix PATH : "$jre/bin"
      done
    '';
  in lib.optionalString hostPlatform.isLinux fixupPhase'linux;

  setupHook = mkFlexSetupHook drv.pname env;

  passthru = env (output: drv.finalPackage.${output});
})

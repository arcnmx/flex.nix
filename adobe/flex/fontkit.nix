{
  stdenvNoCC
, fetchurl
, lib
, self'lib
}: let
sdkJars = {
  afe.sha256 = "sha256-iyfRRXhGOAGH/s2dDijn06QJ+y92H77+YeuTvElsJ7M=";
  aglj40.sha256 = "sha256-0jObihmSzJNAcsn6Z2szuS4cJzQme6B0W6bgZg3UQCI=";
  rideau.sha256 = "sha256-yhb1JhDMptoAenHfUU1AP6tnV3ILCiT5TkCjmqbuK9M=";
  flex-fontkit.sha256 = "sha256-k4eopiXNqiQ+g+I2lELxp2b0sRnmcgHHTyDp0sx00+w=";
};
in stdenvNoCC.mkDerivation (drv: let
  env = placeholder: {
    FLEX_HOME = "${placeholder "out"}/${drv.sdkHome}";
  };
in {
  name = "adobe-flex-sdk-fontkit-deps";
  srcs = lib.mapAttrsToList (name: { sha256 }: fetchurl {
    name = "${name}.jar";
    url = "https://sourceforge.net/adobe/flexsdk/code/HEAD/tree/trunk/lib/${name}.jar?format=raw";
    inherit sha256;
  }) sdkJars;
  unpackPhase = ''
    runHook preUnpack

    for sdkSrc in $srcs; do
      cp $sdkSrc ''${sdkSrc#*-}
    done

    runHook postUnpack
  '';
  sourceRoot = ".";

  inherit (self'lib) sdkHome;
  optDir = "lib/external/optional";
  inherit (env placeholder) FLEX_HOME;

  outputs = [ "out" ];
  sdkJars = lib.attrNames sdkJars;
  installPhase = ''
    runHook preInstall

    install -d $FLEX_HOME/$optDir
    for sdkJar in $sdkJars; do
      install -t $FLEX_HOME/$optDir/ $sdkJar.jar
    done

    #install -Dt $fontkit/$sdkHome/$optDir $FLEX_HOME/$optDir/{flex-fontkit,afe,aglj40,rideau}.jar

    runHook postInstall
  '';

  passthru = env (output: drv.finalPackage.${output}) // {
    fontkit = drv.finalPackage.out;
    optionalDeps = [
      drv.finalPackage.fontkit
    ];
  };
})

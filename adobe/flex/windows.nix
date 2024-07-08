{
  stdenvNoCC
, fetchurl
, unzip
, lib
, self'lib
}: stdenvNoCC.mkDerivation (drv: let
  env = placeholder: {
    FLEX_HOME = "${placeholder "out"}/${drv.sdkHome}";
  };
in {
  pname = "adobe-flex-sdk-windows";
  version = "4.6.0.23201B";
  meta.homepage = "https://flex.apache.org/download-binaries.html";
  src = fetchurl {
    url = "https://fpdownload.adobe.com/pub/flex/sdk/builds/flex${lib.versions.majorMinor drv.version}/flex_sdk_${drv.version}.zip";
    sha256 = "sha256-Yitj8p3kRgD/jUIxF0pw/LMIWBLA4UakLpGHfKi0Z5g=";
  };
  sourceRoot = ".";

  nativeBuildInputs = [ unzip ];

  inherit (self'lib) sdkHome;
  inherit (env placeholder) FLEX_HOME;

  outputs = [ "out" "fontkit" "adt" ];
  installPhase = ''
    runHook preInstall

    install -d $FLEX_HOME $out/bin
    mv ./* $FLEX_HOME/

    find $out -name '*.jar'
    install -Dt $fontkit/$sdkHome/lib/external/optional/ \
      $FLEX_HOME/lib/{flex-fontkit,afe,aglj40,rideau}.jar
    install -Dt $adt/$sdkHome/lib/external/optional/ $FLEX_HOME/lib/adt.jar

    runHook postInstall
  '';

  passthru = env (output: drv.finalPackage.${output}) // {
    optionalDeps = [
      drv.finalPackage.fontkit
      drv.finalPackage.adt
    ];
  };
})

{
  stdenvNoCC
, stdenv
, hostPlatform
, lib
, fetchurl
, autoPatchelfHook
, libglvnd
, pango
, glib
, nss
, nspr
, gtk2-x11
, mkFlexSetupHook
}: let
  stdenv' = if hostPlatform.isLinux then stdenv else stdenvNoCC;
  version = "32";
  mainProgram' =
    if hostPlatform.isWindows then "flashplayer_32_sa_debug"
    else if hostPlatform.isLinux then "flashplayerdebugger"
    else "";
  mainProgram = mainProgram' + hostPlatform.extensions.executable;
  urlPrefix = "https://fpdownload.macromedia.com/pub/flashplayer/updaters/${version}";
in stdenv'.mkDerivation (drv: let
  env = placeholder: {
    FLASHPLAYER_DEBUGGER = "${placeholder "out"}/bin/${mainProgram}";
  };
in {
  pname = "adobe-flash-player-bin-debug";
  inherit version;

  src = if hostPlatform.isWindows then fetchurl {
    url = "${urlPrefix}/${mainProgram}";
    sha256 = "sha256-Y54jOK7lFZWk/12jj3861bKOjHAAIsb4WkAP3HMHPHY=";
  } else if hostPlatform.isLinux then fetchurl {
    url = "${urlPrefix}/flash_player_sa_linux_debug.${hostPlatform.linuxArch}.tar.gz";
    sha256 = "sha256-GtvR8t8TDG9qXp1NoeI1E+bGgu7sDJFTvxe8vsofSsY=";
  } else null;
  sourceRoot = ".";

  nativeBuildInputs = lib.optional hostPlatform.isLinux autoPatchelfHook;
  buildInputs = lib.optionals hostPlatform.isLinux [
    libglvnd
    pango
    glib
    nss
    nspr
    gtk2-x11
  ];

  inherit mainProgram;
  ${if hostPlatform.isWindows then "unpackPhase" else null} = ''
    runHook preUnpack

    cp $src $mainProgram

    runHook postUnpack
  '';

  installPhase = ''
    runHook preInstall

    install -m0755 -Dt $out/bin $mainProgram

    runHook postInstall
  '';

  setupHook = mkFlexSetupHook drv.pname env;

  passthru = env (output: drv.finalPackage.${output});
  meta = {
    inherit mainProgram;
    platforms = lib.platforms.windows ++ [
      "x86_64-linux"
    ];
  };
})

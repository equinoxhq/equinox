{
  lib,
  buildNimPackage,
  clangStdenv,
  fetchFromGitHub,
  makeWrapper,
  wrapGAppsHook4,
  glib,
  libgbinder,
  pcre2,
  gtk4,
  libadwaita,
  openssl,
  curl,
  sqlite,
  zlib-ng,
  mimalloc,
  libbacktrace,
  pkg-config,
  lxc,
  dnsmasq,
  policycoreutils,

  release ? true,
}:
let
  # use clang stdenv
  buildNimPackage' = buildNimPackage.override {
    stdenv = clangStdenv;
  };
  zlib-ng' = zlib-ng.override {
    withZlibCompat = true;
  };

  nim-libbacktrace = clangStdenv.mkDerivation rec {
    name = "nim-libbacktrace";

    src = fetchFromGitHub {
      owner = "status-im";
      repo = name;
      rev = "v0.0.8";
      hash = "sha256-CnmP46QyPsC8c/lChxpRzzITk1Ebi+V+B3mlD0W+G/c=";
      fetchSubmodules = true;
    };

    buildInputs = [
      libbacktrace
    ];

    doCheck = false;

    makeFlags = [
      "CC=clang"
      "CXX=clang++"
      "USE_SYSTEM_LIBS=1"
    ];

    installPhase = ''
      mkdir -p $out
      cp *.nim $out
      cp *.h $out
      cp -r install $out
    '';
  };
  isaac = fetchFromGitHub {
    owner = "pragmagic";
    repo = "isaac";
    rev = "v0.1.3";
    hash = "sha256-3GtG/oC4b41I6E7SHYzvAfYvJ/qLmEOVZDn77350w0M=";
  };
  mimalloc_nim = fetchFromGitHub {
    owner = "planetis-m";
    repo = "mimalloc_nim";
    rev = "v0.3.1";
    hash = "sha256-9zg8KXJ9IL9QC8LsqdO7HUCY9ZqymMsZz/JMUYlYmF8=";
  };
in
buildNimPackage' (self: {
  pname = "equinox";
  version =
    let
      raw = builtins.readFile ../equinox.nimble;
      matches = builtins.match ''.+version = "([^"]+)".+'' raw;
    in
    builtins.head matches;
  src = ../.;

  buildInputs = [
    glib
    libgbinder
    pcre2
    gtk4
    libadwaita
    openssl
    curl
    sqlite
    zlib-ng'
    mimalloc
    libbacktrace
  ];

  nativeBuildInputs = [
    pkg-config
    makeWrapper
    wrapGAppsHook4
  ];

  lockFile = ./lock.json;

  nimRelease = release;
  nimDefines = [
    "useMalloc"
    "useMimalloc"
    "mimallocDynamic" # can't use the vendored mimalloc
    "ssl"
    "nimStackTraceOverride"
    "libbacktraceUseSystemLibs"
    "packagedInstall"
  ];
  nimFlags =
    [
      "--define:adwMinor=6"
      "--cc:clang"
      "--stacktrace:off"
      "--import:libbacktrace"
      "--warning:UnreachableCode:off"
      # workaround for dependencies
      "--path:${nim-libbacktrace}"
      "--path:${isaac}/src"
      "--path:${mimalloc_nim}"
    ]
    ++ (lib.optionals (!self.nimRelease) [
      "--debugger:native"
      ''--passC:"-g3 -O0 -fno-omit-frame-pointer -gdwarf-5"''
    ]);

  patchPhase = ''
    rm -fr config.nims
    # needed for mimalloc dependency
    cat > config.nims <<-EOF
    patchFile("stdlib", "malloc", r"${mimalloc_nim}/src/patchedstd/mimalloc")
    EOF
  '';

  preFixup = ''
    gappsWrapperArgs+=(
      --prefix PATH : ${dnsmasq}/bin
      --prefix PATH : ${lxc}/bin
      --prefix PATH : ${policycoreutils}/bin
      --set LD_LIBRARY_PATH "${lib.makeLibraryPath self.buildInputs}"
    )
  '';

  meta.mainProgram = "equinox_gui";
})

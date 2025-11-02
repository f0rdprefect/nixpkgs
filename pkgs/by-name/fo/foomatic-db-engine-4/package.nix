{
  lib,
  stdenv,
  fetchFromGitHub,
  perl,
  perlPackages,
  libxml2,
  pkg-config,
  bash,
  foomatic-db,
  makeWrapper,
  autoconf,
  automake,
  file,
}:

stdenv.mkDerivation rec {
  pname = "foomatic-db-engine";
  version = "4.0.13";

  src = fetchFromGitHub {
    owner = "OpenPrinting";
    repo = "foomatic-db-engine-4";
    # There are no releases/tags, using the latest commit from the main branch
    # The README says this is version 4.0.13
    rev = "bd265b77a9f66f672bf1e3f0803145f2eccabf06";
    hash = "sha256-egX+cqwE0YQgsI3ADzpzjd9FhBF8N/Hg6a9rsEabo7g=";
  };

  nativeBuildInputs = [
    autoconf
    automake
    pkg-config
    perl
    file
    makeWrapper
  ];

  buildInputs = [
    libxml2
    perl
    bash
  ]
  ++ (with perlPackages; [
    XMLLibXML
    DBI
  ]);

  propagatedBuildInputs = [
    foomatic-db
  ];

  # Make the file utility available during configure
  # sed-substitute indirection is more robust against
  # characters in paths that might need escaping
  prePatch = ''
    sed -Ei 's|^(S?BINSEARCHPATH=).+$|\1"@PATH@"|g' configure.ac
    substituteInPlace configure.ac --subst-var PATH
    touch Makefile.PL  # `buildPerlPackage` fails unless this exists
  '';

  preConfigure = ''
    # Generate configure script
    ./make_configure

    # Make sure Perl can find modules during build
    export PERL5LIB="${
      lib.makeSearchPath "lib/perl5/site_perl" (
        with perlPackages;
        [
          XMLLibXML
          DBI
        ]
      )
    }:$PERL5LIB"
  '';

  configureFlags = [
    "--sysconfdir=${placeholder "out"}/etc"
    "--localstatedir=/var"
    "LIBDIR=${placeholder "out"}/share/foomatic"
    "PERLPREFIX=${placeholder "out"}"
  ];

  postInstall = ''
    # Wrap perl scripts to ensure they can find runtime dependencies
    for file in $out/bin/*; do
      if [[ -f $file && -x $file ]]; then
        wrapProgram $file \
          --prefix PERL5LIB : "${
            lib.makeSearchPath "lib/perl5/site_perl" (
              with perlPackages;
              [
                XMLLibXML
                DBI
              ]
            )
          }" \
          --prefix PATH : "${
            lib.makeBinPath [
              bash
              file
            ]
          }" \
          --set LIBDIR "${foomatic-db}/share/foomatic"
      fi
    done
  '';

  meta = with lib; {
    description = "OpenPrinting printer support database engine (4.0.x series)";
    longDescription = ''
      Foomatic's database engine generates PPD files from the data in
      Foomatic's XML database. It also contains scripts to directly generate
      print queues and handle jobs.

      This is the 4.0.x series which is needed for compatibility with certain
      printer drivers like ptouch-driver, which generate incorrect PPD files
      (with negative margin values) when using newer versions of
      foomatic-db-engine.

      This package should only be used when explicitly needed for compatibility
      reasons. For most printers, the newer foomatic-db-engine package is
      recommended.
    '';
    homepage = "https://github.com/OpenPrinting/foomatic-db-engine-4";
    license = licenses.gpl2Plus;
    maintainers = with maintainers; [ ];
    platforms = platforms.linux;
    # Mark as lower priority than the main foomatic-db-engine to avoid conflicts
    priority = 10;
  };
}

let
  mkSnippet = prefix: body: {
    inherit prefix;
    body = [ body ];
    description = "greek letter ${body}";
  };

  mkSnippets = data: builtins.mapAttrs mkSnippet data;

  greekData = {
    alpha = "α";
    beta = "β";
    gamma = "γ";
    delta = "δ";
    epsilon = "ε";
    zeta = "ζ";
    eta = "η";
    theta = "θ";
    iota = "ι";
    kappa = "κ";
    lambda = "λ";
    mu = "μ";
    nu = "ν";
    xi = "ξ";
    omicron = "ο";
    pi = "π";
    rho = "ρ";
    sigma = "σ";
    tau = "τ";
    upsilon = "υ";
    phi = "φ";
    chi = "χ";
    psi = "ψ";
    omega = "ω";

    ALPHA = "Α";
    BETA = "Β";
    GAMMA = "Γ";
    DELTA = "Δ";
    EPSILON = "Ε";
    ZETA = "Ζ";
    ETA = "Η";
    THETA = "Θ";
    IOTA = "Ι";
    KAPPA = "Κ";
    LAMBDA = "Λ";
    MU = "Μ";
    NU = "Ν";
    XI = "Ξ";
    OMICRON = "Ο";
    PI = "Π";
    RHO = "Ρ";
    SIGMA = "Σ";
    TAU = "Τ";
    UPSILON = "Υ";
    PHI = "Φ";
    CHI = "Χ";
    PSI = "Ψ";
    OMEGA = "Ω";

    "0" = "₀";
    "1" = "₁";
    "2" = "₂";
    "3" = "₃";
    "4" = "₄";
    "5" = "₅";
    "6" = "₆";
    "7" = "₇";
    "8" = "₈";
    "9" = "₉";
  };
in
{
  greek = mkSnippets greekData;
}

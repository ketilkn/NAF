configfile: "config.yml"

rule all:
  input:
    "output/NAFupload.csv",
    "output/rankings.html"

from snakemake.remote.HTTP import RemoteProvider as HTTPRemoteProvider
HTTP = HTTPRemoteProvider()

rule dl_gdata:
  params:
    all_matches_url=config.get('all_matches_url', 'http://ghoulhq.com/nafdata/export/all_matches.csv')
  output:
    csv="data/all_matches.csv.gz"
  shell:
    "curl -L {params.all_matches_url} | gzip > {output}"

rule dl_pdata:
  params:
    all_coaches_url=config.get('all_coaches_url', 'http://ghoulhq.com/nafdata/export/all_coaches.csv')
  output:
    csv="data/all_coaches.csv.gz"
  shell:
    "curl -L {params.all_coaches_url} | gzip > {output}"

rule process_data:
  input:
    csv=rules.dl_gdata.output.csv
  output:
    txt="output/cleaned_games.txt.gz"
  params:
    globalmode=config["global_mode"],
    globalexcl=config["global_excl"]
  script:
    "scripts/process_naf_data.py"

rule compute_rankings:
  input:
    txt=rules.process_data.output.txt,
  output:
    hdf5="output/rankings.h5"
  params:
    mu=config["mu"],
    phi=config["phi"],
    tau=config["tau"],
    sigma=config["sigma"],
    update_freq=config["update_freq"],
    cutoff=config.get("cutoff", None),
    period=config.get("time_period", None)
  script:
    "scripts/run_glicko.py"

rule get_ranks:
  input:
    hdf5=rules.compute_rankings.output.hdf5,
    csv=rules.dl_pdata.output.csv
  output:
    csv="output/player_ranks.csv"
  params:
    phi_penalty=config["phi_penalty"]
  script:
    "scripts/compute_rankings.py"

rule makehtml:
  input:
    csv=rules.get_ranks.output.csv,
  output:
    "output/rankings.html",
  script:
    "scripts/makehtml.py"

rule prep_upload:
  input:
    csv=rules.get_ranks.output.csv
  output:
    upload="output/NAFupload.csv",
    winners="output/winners.csv",
    losers="output/losers.csv",
    races="output/top_by_race.csv"
  params:
    phi_limit=config["phi_limit"],
    phi_active=config["phi_active"],
    phi_penalty=config["phi_penalty"],
    extra_cols=config["extra_cols"],
    globalmode=config["global_mode"]
  script:
    "scripts/prep_upload_csv.py"


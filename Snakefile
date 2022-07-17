import yaml
import os

from snakemake.utils import min_version
from pipeline.bicleaner import packs


min_version("6.6.1")

# `include` directive is not supported by Pycharm plugin, moving all rules to one file to enable live checks
# https://github.com/JetBrains-Research/snakecharm/issues/195


### configuration

container: 'Singularity.sif'

install_deps = config['deps'] == 'true'
data_root_dir = config['root']
cuda_dir = config['cuda']
cudnn_dir = config['cudnn']
gpus_num = config['numgpus']
# marian occupies all GPUs on a machine if `gpus` are not specified
gpus = config['gpus'] if config['gpus'] else ' '.join([str(n) for n in range(int(gpus_num))])
workspace = config['workspace']
marian_cmake = config['mariancmake']

# experiment
src = config['experiment']['src']
trg = config['experiment']['trg']
experiment = config['experiment']['name']

mono_max_sent_src = config['experiment']['mono-max-sentences-src']
mono_max_sent_trg = config['experiment']['mono-max-sentences-trg']
bicl_default_threshold = config['experiment']['bicleaner']['default-threshold']
bicl_dataset_thresholds = config['experiment']['bicleaner']['dataset-thresholds']
backward_pretrained = config['experiment']['backward-model']
vocab_pretrained = config['experiment']['vocab']

try:
    fine_tune_mode = config['experiment']['fine-tune-to-domains']
except KeyError:
    fine_tune_mode = None

experiment_dir=f"{data_root_dir}/experiments/{src}-{trg}/{experiment}"

# override marian configs
marian_args = {name: ' '.join([f'--{k} {v}' for k,v in conf.items() ])
               for name, conf in config['marian-args'].items()}

# datasets
train_datasets = config['datasets']['train']
valid_datasets = config['datasets']['devtest']
eval_datasets = config['datasets']['test']
mono_src_datasets = config['datasets']['mono-src']
mono_trg_datasets = config['datasets']['mono-trg']
mono_datasets = {src: mono_src_datasets, trg: mono_trg_datasets}
mono_max_sent = {src: mono_max_sent_src, trg: mono_max_sent_trg}

try:
    held_out_dev_test = config['datasets']['held-out-dev-test']
except KeyError:
    held_out_dev_test = False
if held_out_dev_test:
    held_out_dev_size = config['datasets']['held-out-dev-size']
    held_out_test_size = config['datasets']['held-out-test-size']

all_eval_datasets = eval_datasets if not held_out_dev_test else eval_datasets + ['held_out_'+dataset
                                                                                 for dataset in train_datasets]

# parallelization

ensemble = list(range(config['experiment']['teacher-ensemble']))
split_length = config['experiment']['split-length']

# logging
log_dir = f"{data_root_dir}/logs/{src}-{trg}/{experiment}"
reports_dir = f"{data_root_dir}/reports/{src}-{trg}/{experiment}"

# binaries
cwd = os.getcwd()
third_party_dir = f'{cwd}/3rd_party'
marian_dir = f'{third_party_dir}/marian-dev/build'
bmt_marian_dir = f'{third_party_dir}/browsermt-marian-dev/build'
trainer = f'{marian_dir}/marian'
decoder = f'{marian_dir}/marian-decoder'
scorer = f'{marian_dir}/marian-scorer'
spm_encoder = f'{marian_dir}/spm_encode'
spm_trainer = f'{marian_dir}/spm_train'
spm_exporter = f'{marian_dir}/spm_export_vocab'
bmt_decoder = f'{bmt_marian_dir}/marian-decoder'
bmt_converter = f'{bmt_marian_dir}/marian-conv'

kenlm = f'{third_party_dir}/kenlm'
fast_align_build = f'{third_party_dir}/fast_align/build'
extract_lex_build = f'{third_party_dir}/extract-lex/build'
preprocess_build_dir=f'{third_party_dir}/preprocess/build'
bin = f'{cwd}/bin'
deduper = f'{cwd}/bin/dedupe'

# data
data_dir = f"{data_root_dir}/data/{src}-{trg}/{experiment}"
clean = f"{data_dir}/clean"
biclean = f"{data_dir}/biclean"
cache_dir = f"{data_dir}/cache"
original = f"{data_dir}/original"
translated = f"{data_dir}/translated"
augmented = f"{data_dir}/augmented"
merged = f"{data_dir}/merged"
filtered = f'{data_dir}/filtered'
align_dir = f"{data_dir}/alignment"

translated_domains = f"{data_dir}/translated-domains"

# models
models_dir = f"{data_root_dir}/models/{src}-{trg}/{experiment}"
teacher_base_dir = f"{models_dir}/teacher-base"
teacher_finetuned_dir = f"{models_dir}/teacher-finetuned"
student_dir = f"{models_dir}/student"
student_finetuned_dir = f"{models_dir}/student-finetuned"
speed_dir = f"{models_dir}/speed"
exported_dir = f"{models_dir}/exported"
best_model = f"final.model.npz.best-{config['experiment']['best-model']}.npz"
backward_dir = f'{models_dir}/backward'
spm_sample_size=config['experiment']['spm-sample-size']
vocab_path=vocab_pretrained or f"{models_dir}/vocab/vocab.spm"

domain_finetuned_teacher_dir = f"{models_dir}/teacher-domain-ft"

# clustering params
try:
    num_clusters = config['experiment']['num-clusters']
except KeyError:
    num_clusters = 8

try:
    vector_layer_num = config['experiment']['vector-layer-num']
except KeyError:
    vector_layer_num = 4

clustering_teacher_id = "0"

cluster_data_dir = f"{data_dir}/clusters/teacher{clustering_teacher_id}"
orig_cluster_data_dir = f"{cluster_data_dir}/original"
embedded_cluster_data_dir = f"{cluster_data_dir}/embedded"
labels_cluster_data_dir = f"{cluster_data_dir}/labels"
split_cluster_data_dir = f"{cluster_data_dir}/split"
embedded_source_postfix = "embedded_source.npz"
cluster_labels_postfix = "cluster_labels.txt"
cluster_models_dir = f"{models_dir}/clustering/teacher{clustering_teacher_id}"
clustered_train_postfix = "corpus_cluster"
# TODO: a better way to do this
vocab_file_path = vocab_path[:-3] + "vocab"
hf_model_dir = f"{cluster_models_dir}-huggingface"
hf_caching_dir = f"{cluster_data_dir}/.hf_cache/datasets"
kmeans_model_postfix = "kmeans_model.dump"
hf_conversion_outputs = ["config.json", "pytorch_model.bin", "special_tokens_map.json",
                         "tokenizer_config.json", "marian_original_config.json",
                         "source.spm", "target.spm", "vocab.json"]

#evaluation
eval_data_dir = f"{original}/eval"
eval_res_dir = f"{models_dir}/evaluation"
eval_backward_dir = f'{eval_res_dir}/backward'
eval_student_dir = f'{eval_res_dir}/student'
eval_student_finetuned_dir = f'{eval_res_dir}/student-finetuned'
eval_speed_dir = f'{eval_res_dir}/speed'
eval_teacher_ens_dir = f'{eval_res_dir}/teacher-ensemble'

eval_corpus_ft_teachers_dir = f"{models_dir}/evaluation-domain-ft"
eval_corpus_ft_teacher_ens_dir = f"{eval_corpus_ft_teachers_dir}/teacher-domain-ft-ensemble"

# set common environment variables
envs = f'''SRC={src} TRG={trg} MARIAN="{marian_dir}" BMT_MARIAN="{bmt_marian_dir}" GPUS="{gpus}" WORKSPACE={workspace} \
BIN="{bin}" CUDA_DIR="{cuda_dir}" CUDNN_DIR="{cudnn_dir}" '''
# CUDA_VISIBLE_DEVICES is used by bicleaner ai. slurm sets this variable
# it can be overriden manually by 'gpus' config setting to split GPUs in local mode
if config['gpus']:
    envs += f' CUDA_VISIBLE_DEVICES="{gpus}" '

### workflow options

results = [f'{exported_dir}/model.{src}{trg}.intgemm.alphas.bin.gz',
           f'{exported_dir}/lex.50.50.{src}{trg}.s2t.bin.gz',
           f'{exported_dir}/vocab.{src}{trg}.spm.gz',
           f'{experiment_dir}/config.yml',
           *expand(f'{eval_res_dir}/teacher-base{{ens}}/{{dataset}}.metrics',ens=ensemble, dataset=all_eval_datasets),
           *expand(f'{eval_student_dir}/{{dataset}}.metrics', dataset=all_eval_datasets),
           *expand(f'{eval_student_finetuned_dir}/{{dataset}}.metrics', dataset=all_eval_datasets),
           *expand(f'{eval_speed_dir}/{{dataset}}.metrics', dataset=all_eval_datasets)
           ]

if len(ensemble) > 1:
    results.extend(expand(f'{eval_teacher_ens_dir}/{{dataset}}.metrics', dataset=all_eval_datasets))

if install_deps:
    results.append("/tmp/flags/setup.done")
#
if not backward_pretrained:
    # don't evaluate pretrained model
    results.extend(expand(f'{eval_backward_dir}/{{dataset}}.metrics',dataset=all_eval_datasets))
    do_train_backward=True
else:
    do_train_backward = False
    backward_dir = backward_pretrained

if fine_tune_mode == "corpus":
    results.extend(expand(f'{eval_corpus_ft_teachers_dir}/teacher-domain-ft{{ens}}/{{dataset}}/{{eval_dataset}}.metrics',
        ens=ensemble, eval_dataset=all_eval_datasets, dataset=train_datasets))

    if len(ensemble) > 1:
        results.extend(expand(f'{eval_corpus_ft_teacher_ens_dir}/{{dataset}}/{{eval_dataset}}.metrics',
            eval_dataset=all_eval_datasets, dataset=train_datasets))

if fine_tune_mode == "cluster":
    results.extend(expand(f'{domain_finetuned_teacher_dir}{{ens}}/{{dataset}}/{best_model}',
            ens=[0],
            dataset=list(range(num_clusters))))

    results.extend(expand(f'{eval_corpus_ft_teachers_dir}/teacher-domain-ft{{ens}}/{{eval_dataset}}.metrics',
        ens=ensemble, eval_dataset=all_eval_datasets))

    if len(ensemble) > 1:
        results.extend(expand(f'{eval_corpus_ft_teacher_ens_dir}/{{eval_dataset}}.metrics',
            eval_dataset=all_eval_datasets))

# bicleaner

bicleaner_type = packs.find(src, trg)
bicleaner_env = "envs/bicleaner-ai.yml" if bicleaner_type == 'bicleaner-ai' else 'envs/bicleaner.yml'

if bicleaner_type:
    clean_corpus_prefix = f'{biclean}/corpus'
    teacher_corpus = f'{biclean}/corpus'
    use_bicleaner = True
else:
    clean_corpus_prefix = f'{clean}/corpus'
    teacher_corpus = f'{clean}/corpus'
    use_bicleaner = False

clean_corpus_src = f'{clean_corpus_prefix}.{src}.gz'
clean_corpus_trg = f'{clean_corpus_prefix}.{trg}.gz'

clean_corpus_domain_ft_prefix = f'{data_dir}/deduplicated/corpus'
clean_corpus_domain_ft_src = f'{clean_corpus_domain_ft_prefix}.{src}.gz'
clean_corpus_domain_ft_trg = f'{clean_corpus_domain_ft_prefix}.{trg}.gz'

# if using held-out dev and test sets,
# the clean corpus only contains the training set
held_out_corpus_prefix = f'{data_dir}/held-out/corpus'
held_out_corpus_src = f'{held_out_corpus_prefix}.{src}.gz'
held_out_corpus_trg = f'{held_out_corpus_prefix}.{trg}.gz'


# augmentation

if mono_trg_datasets:
    teacher_corpus = f'{augmented}/corpus'
    augment_corpus = True
    final_teacher_dir = teacher_finetuned_dir
    results.extend(expand(f'{eval_res_dir}/teacher-finetuned{{ens}}/{{dataset}}.metrics',ens=ensemble, dataset=eval_datasets))
else:
    augment_corpus = False
    final_teacher_dir = teacher_base_dir


### helper functions

def find_parts(wildcards, checkpoint):
    checkpoint_output = checkpoint.get(**wildcards).output[0]
    return glob_wildcards(os.path.join(checkpoint_output,"file.{part,\d+}")).part

def dataset_norm(name: str):
    return name.replace('/','_')

def get_args(section):
    return marian_args.get(section) or ""


### rules

shell.prefix(f"{envs} ")

rule all:
    input: results

localrules: experiment

rule experiment:
    message: "Saving experiment metadata"
    output: f'{experiment_dir}/config.yml'
    priority: 100
    run:
        os.makedirs(experiment_dir, exist_ok=True)
        with open(f'{experiment_dir}/config.yml', 'w') as f:
            yaml.dump(config, f)

# todo: fix jobs grouping in cluster mode


# setup

if install_deps:
    rule setup:
        message: "Installing dependencies"
        log: f"{log_dir}/install-deps.log"
        conda: "envs/base.yml"
        priority: 99
        # group: 'setup'
        output: touch("/tmp/flags/setup.done")  # specific to local machine
        shell: 'bash pipeline/setup/install-deps.sh >> {log} 2>&1'

rule marian:
    message: "Compiling marian"
    log: f"{log_dir}/compile-{{marian_type}}.log"
    conda: "envs/base.yml"
    threads: 16
    resources: gpu=1
 #   group: 'setup'
    output:
        trainer=protected(f"{third_party_dir}/{{marian_type}}/build/marian"),
        decoder=protected(f"{third_party_dir}/{{marian_type}}/build/marian-decoder"),
        scorer=protected(f"{third_party_dir}/{{marian_type}}/build/marian-scorer"),
        converter=protected(f'{third_party_dir}/{{marian_type}}/build/marian-conv'),
        spm_trainer=protected(f'{third_party_dir}/{{marian_type}}/build/spm_train'),
        spm_encoder=protected(f'{third_party_dir}/{{marian_type}}/build/spm_encode'),
        spm_exporter=protected(f'{third_party_dir}/{{marian_type}}/build/spm_export_vocab')
    params: build_dir=f'{third_party_dir}/{{marian_type}}/build'
    shell: 'bash pipeline/setup/compile-marian.sh {params.build_dir} {threads} {marian_cmake} >> {log} 2>&1'

rule fast_align:
    message: "Compiling fast align"
    log: f"{log_dir}/compile-fast-align.log"
    conda: "envs/base.yml"
    threads: 4
#    group: 'setup'
    output: fast_align=protected(f"{bin}/fast_align"), atools=protected(f"{bin}/atools")
    shell: 'bash pipeline/setup/compile-fast-align.sh {fast_align_build} {threads}  >> {log} 2>&1'

rule compile_preprocess:
    message: "Compiling preprocess"
    log: f"{log_dir}/compile-preprocess.log"
    conda: "envs/base.yml"
    threads: 4
    # group: 'setup'
    output: deduper=f'{bin}/dedupe'
    shell: 'bash pipeline/setup/compile-preprocess.sh {preprocess_build_dir} {threads}  >> {log} 2>&1'

rule extract_lex:
    message: "Compiling fast align"
    log: f"{log_dir}/compile-extract-lex.log"
    conda: "envs/base.yml"
    threads: 4
#    group: 'setup'
    output: protected(f"{bin}/extract_lex")
    shell: 'bash pipeline/setup/compile-extract-lex.sh {extract_lex_build} {threads} >> {log} 2>&1'

# data downloading

rule download_corpus:
    message: "Downloading parallel corpus"
    log: f"{log_dir}/download_corpus/{{kind}}/{{dataset}}.log"
    conda: "envs/base.yml"
    threads: 1
#    group: 'data'
    cache: False # caching is broken in snakemake
    wildcard_constraints:
        kind="corpus|devset|eval",
        dataset="(?!held_out_).+"
    output: multiext(f"{original}/{{kind}}/{{dataset}}", f".{src}.gz", f".{trg}.gz")
    params: prefix=f"{original}/{{kind}}/{{dataset}}", dataset="{dataset}"
    shell: 'bash pipeline/data/download-corpus.sh "{params.dataset}" "{params.prefix}"  >> {log} 2>&1'

rule download_mono:
    message: "Downloading monolingual dataset"
    log: f"{log_dir}/download_mono/{{dataset}}.{{lang}}.log"
    conda: "envs/base.yml"
    threads: 1
#    group: 'data'
    cache: False # caching is broken in snakemake
    wildcard_constraints: lang=f"{src}|{trg}"
    output: f'{original}/mono/{{dataset}}.{{lang}}.gz'
    params: max_sent=lambda wildcards: mono_max_sent[wildcards.lang], dataset='{dataset}', lang='{lang}'
    shell: '''bash pipeline/data/download-mono.sh \
                "{params.dataset}" {params.lang} {params.max_sent} "{output}"  >> {log} 2>&1'''

# cleaning

rule clean_corpus:
    message: "Cleaning dataset"
    log: f"{log_dir}/clean_corpus/{{dataset}}.log"
    conda: "envs/base.yml"
#    group: "clean_corpus"
    threads: workflow.cores
    input: multiext(f"{original}/corpus/{{dataset}}", f".{src}.gz", f".{trg}.gz")
    output: multiext(f"{clean}/corpus/{{dataset}}", f".{src}.gz", f".{trg}.gz")
    params: prefix_input=f"{original}/corpus/{{dataset}}",prefix_output=f"{clean}/corpus/{{dataset}}",
            dataset=lambda wildcards: dataset_norm(wildcards.dataset)
    shell: '''bash pipeline/clean/clean-corpus.sh "{params.prefix_input}" "{params.prefix_output}" {threads} {params.dataset} \
                >> {log} 2>&1'''

rule clean_mono:
    message: "Cleaning monolingual dataset"
    log: f"{log_dir}/clean_mono/{{dataset}}.{{lang}}.log"
    conda: "envs/base.yml"
    threads: workflow.cores
#    group: "clean_mono{lang}"
    cache: False
    wildcard_constraints: lang=f"{src}|{trg}"
    input: f'{original}/mono/{{dataset}}.{{lang}}.gz'
    output: f'{clean}/mono/{{dataset}}.{{lang}}.gz'
    params: prefix_input=f"{original}/mono/{{dataset}}", prefix_output=f"{clean}/mono/{{dataset}}",
            dataset=lambda wildcards: dataset_norm(wildcards.dataset)
    shell: '''bash pipeline/clean/clean-mono.sh {wildcards.lang} "{params.prefix_input}" "{params.prefix_output}" \
                {threads} {params.dataset} >> {log} 2>&1'''

if use_bicleaner:
    rule kenlm:
        message: "Installing kenlm"
        log: f"{log_dir}/kenlm.log"
        conda: bicleaner_env
        threads: 4
#        group: 'setup'
        output: directory(f"{bin}/kenlm")
        shell: 'bash pipeline/setup/install-kenlm.sh {kenlm} {threads}  >> {log} 2>&1'

    rule bicleaner_pack:
        message: f"Downloading language pack for bicleaner"
        log: f"{log_dir}/bicleaner_pack.log"
        conda: bicleaner_env
#        group: "clean_corpus"
        threads: 1
        input: rules.kenlm.output
        output: directory(f"{biclean}/pack")
        shell: '''bash pipeline/bicleaner/download-pack.sh "{output}" {bicleaner_type} >> {log} 2>&1'''

    rule bicleaner:
        message: f"Cleaning corpus using {bicleaner_type}"
        log: f"{log_dir}/bicleaner/{{dataset}}.log"
        conda: bicleaner_env
#       group: "bicleaner"
        threads: gpus_num * 2 if bicleaner_type == "bicleaner-ai" else workflow.cores
        resources: gpu=gpus_num if bicleaner_type == "bicleaner-ai" else 0
        input: ancient(rules.kenlm.output), multiext(f"{clean}/corpus/{{dataset}}", f".{src}.gz", f".{trg}.gz"),
                pack_dir=rules.bicleaner_pack.output
        output: multiext(f"{biclean}/corpus/{{dataset}}", f".{src}.gz", f".{trg}.gz")
        params:
            prefix_input=f"{clean}/corpus/{{dataset}}",prefix_output=f"{biclean}/corpus/{{dataset}}",
            threshold=lambda wildcards: bicl_dataset_thresholds[wildcards.dataset]
                                            if wildcards.dataset in bicl_dataset_thresholds
                                            else bicl_default_threshold
        shell: '''bash pipeline/bicleaner/bicleaner.sh \
                    "{params.prefix_input}" "{params.prefix_output}" {params.threshold} {bicleaner_type} {threads} \
                    "{input.pack_dir}" >> {log} 2>&1'''

# Create held-out dev and test sets if needed
# (necessary for domain fine-tuning to evaluate fine-tuned models on relevant data)
if held_out_dev_test:
    rule deduplicate_individual_corpora:
        message: "Deduplicating each corpus independently"
        log: f"{log_dir}/deduplicate_individual_corpora_{{dataset}}.log"
        conda: "envs/base.yml"
        threads: workflow.cores
        #group: "clean_corpus"
        input:
            expand(f"{clean_corpus_prefix}/{{dataset}}.{{lang}}.gz", lang=[src, trg], allow_missing=True)
        output:
            src=f"{clean_corpus_domain_ft_prefix}/{{dataset}}.{src}.gz",
            trg=f"{clean_corpus_domain_ft_prefix}/{{dataset}}.{trg}.gz"
        params:
            prefix_output=f"{clean_corpus_domain_ft_prefix}/{{dataset}}",
            prefix_input=f"{clean_corpus_prefix}/{{dataset}}"
        shell: '''bash pipeline/clean/tools/individual-deduplication.sh "{params.prefix_output}" \
                    {params.prefix_input} >> {log} 2>&1'''

    rule create_held_out_sets:
        message: "Creating held-out dev and test sets for each corpus"
        log: f"{log_dir}/create_held_out_sets_{{dataset}}.log"
        conda: "envs/base.yml"
        threads: workflow.cores
        #group: "clean_corpus"
        wildcard_constraints: dataset="|".join(train_datasets)
        input:
            src=f"{clean_corpus_domain_ft_prefix}/{{dataset}}.{src}.gz",
            trg=f"{clean_corpus_domain_ft_prefix}/{{dataset}}.{trg}.gz"
        output:
            src_train=f"{held_out_corpus_prefix}/train/{{dataset}}.{src}.gz",
            trg_train=f"{held_out_corpus_prefix}/train/{{dataset}}.{trg}.gz",
            src_dev=f"{held_out_corpus_prefix}/dev/{{dataset}}.{src}.gz",
            trg_dev=f"{held_out_corpus_prefix}/dev/{{dataset}}.{trg}.gz",
            src_test=f"{held_out_corpus_prefix}/test/{{dataset}}.{src}.gz",
            trg_test=f"{held_out_corpus_prefix}/test/{{dataset}}.{trg}.gz",
        params:
            dev_size=held_out_dev_size,
            test_size=held_out_test_size
        shell: '''bash pipeline/data/held-out-dev-test.sh \
                    "{input.src}" "{input.trg}" "{params.dev_size}" "{params.test_size}" \
                    "{held_out_corpus_prefix}" "{wildcards.dataset}" >> {log} 2>&1'''

    rule merge_held_out_train_sets:
        message: "Merge held-out train sets"
        log: f"{log_dir}/merge_held_out_train_sets.log"
        conda: "envs/base.yml"
        threads: workflow.cores
        #group: "clean_corpus"
        input:
            expand(f"{held_out_corpus_prefix}/train/{{dataset}}.{{lang}}.gz",
                dataset=train_datasets,lang=[src, trg])
        output:
            src=clean_corpus_src,
            trg=clean_corpus_trg
        params:
            prefix_output=clean_corpus_prefix,
            prefixes=expand(f"{held_out_corpus_prefix}/train/{{dataset}}",dataset=train_datasets)
        shell: '''bash pipeline/clean/merge-corpus.sh "{params.prefix_output}" {params.prefixes} >> {log} 2>&1'''

    rule copy_held_out_test_sets:
        message: "Copy held-out test sets to eval directory"
        log: f"{log_dir}/copy_held_out_test_sets_{{dataset}}.log"
        conda: "envs/base.yml"
        threads: workflow.cores
        #group: "clean_corpus"
        input:
            input_src=f"{held_out_corpus_prefix}/test/{{dataset}}.{src}.gz",
            input_trg=f"{held_out_corpus_prefix}/test/{{dataset}}.{trg}.gz"
        output:
            src=f"{eval_data_dir}/held_out_{{dataset}}.{src}.gz",
            trg=f"{eval_data_dir}/held_out_{{dataset}}.{trg}.gz"
        shell: '''cp {input.input_src} {output.src} >> {log} 2>&1
                  cp {input.input_trg} {output.trg} >> {log} 2>&1'''

# If using held-out dev and test sets, the merged train sets will be used (created by rule merge_held_out_train_sets),
# so that the model does not see dev and test data that will be used for fine-tuning teachers to corpora;
# if no held-out sets, use the original merge_corpus rule
if not held_out_dev_test:
    rule merge_corpus:
        message: "Merging clean parallel datasets"
        log: f"{log_dir}/merge_corpus.log"
        conda: "envs/base.yml"
        threads: workflow.cores
        # group: "clean_corpus"
        input:  expand(f"{clean_corpus_prefix}/{{dataset}}.{{lang}}.gz", dataset=train_datasets, lang=[src, trg]),
                bin=ancient(deduper)
        output: src=clean_corpus_src,trg=clean_corpus_trg
        params: prefix_output=clean_corpus_prefix, prefixes=expand(f"{clean_corpus_prefix}/{{dataset}}", dataset=train_datasets)
        shell: '''bash pipeline/clean/merge-corpus.sh "{params.prefix_output}" {params.prefixes} >> {log} 2>&1'''

# Merge individually deduplicated training corpora (used to compare files after forward-translation)
if fine_tune_mode == "corpus":
    rule merge_corpus_for_forward_translation:
        message: "Merging clean parallel datasets for domain fine-tuning (with individual deduplication)"
        log: f"{log_dir}/merge_corpus_for_forward_translation.log"
        conda: "envs/base.yml"
        threads: workflow.cores
        group: "clean_corpus"
        input: expand(f"{held_out_corpus_prefix}/train/{{dataset}}.{{lang}}.gz",dataset=train_datasets,lang=[src, trg])
        output:
            src=clean_corpus_domain_ft_src,
            trg=clean_corpus_domain_ft_trg
        params:
            prefix_output=clean_corpus_domain_ft_prefix,
            prefixes=expand(f"{held_out_corpus_prefix}/train/{{dataset}}",
            dataset=train_datasets)
        shell: '''bash pipeline/clean/merge-corpus-without-deduplication.sh \
                    "{params.prefix_output}" {params.prefixes} >> {log} 2>&1'''

rule merge_devset:
    message: "Merging devsets"
    log: f"{log_dir}/merge_devset.log"
    conda: "envs/base.yml"
    threads: workflow.cores
    # group: "clean_corpus"
    input:  expand(f"{original}/devset/{{dataset}}.{{lang}}.gz", dataset=valid_datasets, lang=[src, trg]),
            bin=ancient(deduper)
    output: multiext(f"{original}/devset", f".{src}.gz", f".{trg}.gz")
    params: prefix_output=f"{original}/devset", prefixes=expand(f"{original}/devset/{{dataset}}", dataset=valid_datasets)
    shell: '''bash pipeline/clean/merge-corpus.sh "{params.prefix_output}" {params.prefixes} >> {log} 2>&1'''

if fine_tune_mode == "cluster":
    rule merge_all_devsets:
        message: "Merging all devsets for cluster fine-tuning"
        log: f"{log_dir}/merge_all_devsets_for_clustering.log"
        conda: "envs/base.yml"
        threads: workflow.cores
        # group: "clean_corpus"
        input: rules.merge_devset.output,
               expand(f"{held_out_corpus_prefix}/dev/{{dataset}}.{{lang}}.gz", dataset=train_datasets, lang=[src, trg])
        # output: multiext(f"{orig_cluster_data_dir}/dev/devset", f".{src}.gz", f".{trg}.gz")
        output: multiext(f"{original}/devset/merged_devset", f".{src}.gz", f".{trg}.gz")
        params:
            # prefix_output=f"{orig_cluster_data_dir}/dev/devset",
            prefix_output = f"{original}/devset/merged_devset",
            external_dev_prefix=f"{original}/devset",
            held_out_prefixes=expand(f"{held_out_corpus_prefix}/dev/{{dataset}}", dataset=train_datasets)
        shell: '''bash pipeline/clean/merge-corpus.sh "{params.prefix_output}" {params.external_dev_prefix} {params.held_out_prefixes} >> {log} 2>&1'''

rule merge_mono:
    message: "Merging clean monolingual datasets"
    log: f"{log_dir}/merge_mono_{{lang}}.log"
    conda: "envs/base.yml"
    threads: workflow.cores
    #group "clean_mono{lang}"
    input:
        corpora=lambda wildcards: expand(f"{clean}/mono/{{dataset}}.{{lang}}.gz",
            dataset=mono_datasets[wildcards.lang], lang=wildcards.lang),
            bin=ancient(deduper)
    output: f"{clean}/mono.{{lang}}.gz"
    params: max_sent=lambda wildcards: mono_max_sent[wildcards.lang]
    shell: '''bash pipeline/clean/merge-mono.sh "{output}" {params.max_sent} {input.corpora} >> {log} 2>&1'''

# augmentation and teacher training

if not vocab_pretrained:
    rule train_vocab:
        message: "Training spm vocab"
        log: f"{log_dir}/train_vocab.log"
        conda: "envs/base.yml"
        threads: 2
        input: bin=ancient(spm_trainer), corpus_src=clean_corpus_src, corpus_trg=clean_corpus_trg
        output: vocab_path
        params: prefix_train=clean_corpus_prefix,prefix_test=f"{original}/devset"
        shell: '''bash pipeline/train/spm-vocab.sh "{input.corpus_src}" "{input.corpus_trg}" "{output}" {spm_sample_size} \
                    >> {log} 2>&1'''

if do_train_backward:
    rule train_backward:
        message: "Training backward model"
        log: f"{log_dir}/train_backward.log"
        conda: "envs/base.yml"
        threads: gpus_num * 2
        resources: gpu=gpus_num
        #group 'backward'
        input:
            rules.merge_devset.output, train_src=clean_corpus_src,train_trg=clean_corpus_trg,
            bin=ancient(trainer), vocab=vocab_path,
        output:  model=f'{backward_dir}/{best_model}'
        params: prefix_train=clean_corpus_prefix,prefix_test=f"{original}/devset",
                args=get_args("training-backward")
        shell: '''bash pipeline/train/train.sh \
                    backward train {trg} {src} "{params.prefix_train}" "{params.prefix_test}" "{backward_dir}" \
                    "{input.vocab}" {params.args} >> {log} 2>&1'''

if augment_corpus:
    checkpoint split_mono_trg:
        message: "Splitting monolingual trg dataset"
        log: f"{log_dir}/split_mono_trg.log"
        conda: "envs/base.yml"
        threads: 1
        input: corpora=f"{clean}/mono.{trg}.gz", bin=ancient(deduper)
        output: directory(f'{translated}/mono_trg')
        shell: 'bash pipeline/translate/split-mono.sh {input.corpora} {output} {split_length} >> {log} 2>&1'

    rule translate_mono_trg:
        message: "Translating monolingual trg dataset with backward model"
        log: f"{log_dir}/translate_mono_trg/{{part}}.log"
        conda: "envs/base.yml"
        threads: gpus_num * 2
        resources: gpu=gpus_num
        input:
            bin=ancient(decoder), file=f'{translated}/mono_trg/file.{{part}}',
            vocab=vocab_path, model=f'{backward_dir}/{best_model}'
        output: f'{translated}/mono_trg/file.{{part}}.out'
        params: args = get_args("decoding-backward")
        shell: '''bash pipeline/translate/translate.sh "{input.file}" "{input.vocab}" {input.model} {params.args} \
                >> {log} 2>&1'''

    rule collect_mono_trg:
        message: "Collecting translated mono trg dataset"
        log: f"{log_dir}/collect_mono_trg.log"
        conda: "envs/base.yml"
        threads: 4
        #group 'mono_trg'
        input:
            lambda wildcards: expand(f"{translated}/mono_trg/file.{{part}}.out",
                part=find_parts(wildcards, checkpoints.split_mono_trg))
        output: f'{translated}/mono.{src}.gz'
        params: src_mono=f"{clean}/mono.{trg}.gz",dir=directory(f'{translated}/mono_trg')
        shell: 'bash pipeline/translate/collect.sh "{params.dir}" "{output}" "{params.src_mono}" >> {log} 2>&1'

    rule merge_augmented:
        message: "Merging augmented dataset"
        log: f"{log_dir}/merge_augmented.log"
        conda: "envs/base.yml"
        threads: 4
        #group 'mono_trg'
        input:
            src1=clean_corpus_src,src2=rules.collect_mono_trg.output,
            trg1=clean_corpus_trg,trg2=rules.split_mono_trg.input,
            bin=ancient(deduper)
        output: res_src=f'{augmented}/corpus.{src}.gz',res_trg=f'{augmented}/corpus.{trg}.gz'
        shell: '''bash pipeline/translate/merge-corpus.sh \
                    "{input.src1}" "{input.src2}" "{input.trg1}" "{input.trg2}" "{output.res_src}" "{output.res_trg}" \
                      >> {log} 2>&1'''

rule train_teacher:
    message: "Training teacher on all data"
    log: f"{log_dir}/train_teacher{{ens}}.log"
    conda: "envs/base.yml"
    threads: gpus_num*2
    resources: gpu=gpus_num
    input:
        rules.merge_devset.output, train_src=f'{teacher_corpus}.{src}.gz',train_trg=f'{teacher_corpus}.{trg}.gz',
        bin=ancient(trainer), vocab=vocab_path
    output: model=f'{teacher_base_dir}{{ens}}/{best_model}'
    params: prefix_train=teacher_corpus, prefix_test=f"{original}/devset", dir=directory(f'{teacher_base_dir}{{ens}}'),
            args=get_args("training-teacher-base")
    shell: '''bash pipeline/train/train.sh \
                teacher train {src} {trg} "{params.prefix_train}" "{params.prefix_test}" "{params.dir}" \
                "{input.vocab}" {params.args} >> {log} 2>&1'''

if augment_corpus:
    rule finetune_teacher:
        message: "Finetune teacher on parallel corpus"
        log: f"{log_dir}/finetune_teacher{{ens}}.log"
        conda: "envs/base.yml"
        threads: gpus_num * 2
        resources: gpu=gpus_num
        input:
            rules.merge_devset.output, model=f'{teacher_base_dir}{{ens}}/{best_model}',
            train_src=clean_corpus_src, train_trg=clean_corpus_trg,
            bin=ancient(trainer), vocab=vocab_path
        output: model=f'{teacher_finetuned_dir}{{ens}}/{best_model}'
        params: prefix_train=clean_corpus_prefix, prefix_test=f"{original}/devset",
                dir=directory(f'{teacher_finetuned_dir}{{ens}}'),
                args=get_args("training-teacher-finetuned")
        shell: '''bash pipeline/train/train.sh \
                    teacher train {src} {trg} "{params.prefix_train}" "{params.prefix_test}" "{params.dir}" \
                    "{input.vocab}" --pretrained-model "{input.model}" {params.args} >> {log} 2>&1'''

if fine_tune_mode == "cluster":
    rule convert_teacher_to_hf:
        message: "Convert teacher to HuggingFace format"
        log: f"{log_dir}/convert_teacher{{ens}}_to_hf.log"
        conda: "envs/huggingface.yml"
        threads: 4
        input:
            general_teacher=f'{final_teacher_dir}{{ens}}/{best_model}',
            spm_vocab=vocab_path,
        output: expand(f"{hf_model_dir}{{ens}}/{{file}}", file=hf_conversion_outputs, allow_missing=True)
        params:
            dest_dir=f'{hf_model_dir}{{ens}}',
            decoder_config=f'{final_teacher_dir}{{ens}}/{best_model}.decoder.yml',
            vocab=vocab_file_path
        shell: '''python {third_party_dir}/domain_clusters/convert_marian_bergamot_to_pytorch_.py \
                    --npz-model-path "{input.general_teacher}" --yml-decoder-path "{params.decoder_config}" \
                    --spm-model-path "{input.spm_vocab}" --vocab-path "{params.vocab}" --dest-dir "{params.dest_dir}" >> {log} 2>&1'''

    rule make_symlinks_for_clustering:
        message: "Create symlinks to corpora for unified clustering"
        log: f"{log_dir}/create_symlinks.log"
        conda: "envs/base.yml"
        threads: 1
        input:
            train_corpora=multiext(clean_corpus_prefix, f".{src}.gz", f".{trg}.gz"),
            test_corpora=expand(f'{eval_data_dir}/{{dataset}}.{{lang}}.gz', lang=[src, trg], dataset=all_eval_datasets),
            dev_corpora=multiext(f"{original}/devset/merged_devset", f".{src}.gz", f".{trg}.gz")
        output:
            train_links=multiext(f"{orig_cluster_data_dir}/train/corpus", f".{src}.gz", f".{trg}.gz"),
            test_links=expand(f'{orig_cluster_data_dir}/test/{{dataset}}.{{lang}}.gz', lang=[src, trg], dataset=all_eval_datasets),
            dev_links=multiext(f"{orig_cluster_data_dir}/dev/devset", f".{src}.gz", f".{trg}.gz")
        shell: '''python pipeline/clusters/create_symlinks.py \
                    --files {input.train_corpora} {input.test_corpora} {input.dev_corpora} \
                    --links {output.train_links} {output.test_links} {output.dev_links} >> {log} 2>&1'''

    # This rule is used to extract sentence representations from training files split into parts
    # (parts generated by split_corpus)
    rule extract_sentence_representations_from_parts:
        message: "Extract sentence representations for clustering from split files"
        log: f"{log_dir}/extract_reprs_train_{{part}}_teacher{clustering_teacher_id}.log"
        conda: "envs/huggingface.yml"
        threads: 2
        resources: gpu=1
        input:
            input_data=f'{translated}/corpus/file.{{part}}',
            # input_data=f"{orig_cluster_data_dir}/{{dataset}}.{src}.gz",
            hf_model=f"{hf_model_dir}{clustering_teacher_id}/pytorch_model.bin"
        output: f"{embedded_cluster_data_dir}/train/{{part}}_{embedded_source_postfix}"
        params:
            hf_teacher_dir=f"{hf_model_dir}{clustering_teacher_id}",
            layer_num=vector_layer_num,
            batch_size=200,
            hf_caching_dir=hf_caching_dir
        shell: '''bash pipeline/clusters/extract_sentence_representations_parts.sh \
                    "{input.input_data}" "{params.hf_teacher_dir}" "{params.batch_size}" \
                    "{params.layer_num}" "{output}" "{params.hf_caching_dir}" >> {log} 2>&1'''

    rule extract_sentence_representations:
        message: "Extract sentence representations for clustering"
        log: f"{log_dir}/extract_reprs_{{dataset}}_teacher{clustering_teacher_id}.log"
        conda: "envs/huggingface.yml"
        threads: 2
        resources: gpu=1
        # wildcard_constraints: dataset="dev|test"
        input:
            input_data=f"{orig_cluster_data_dir}/{{dataset}}.{src}.gz",
            hf_model=f"{hf_model_dir}{clustering_teacher_id}/pytorch_model.bin"
        output: f"{embedded_cluster_data_dir}/{{dataset}}/{embedded_source_postfix}"
        params:
            hf_teacher_dir=f"{hf_model_dir}{clustering_teacher_id}",
            layer_num=vector_layer_num,
            batch_size=200,
            hf_caching_dir=hf_caching_dir
        shell: '''bash pipeline/clusters/extract_sentence_representations.sh \
                    "{input.input_data}" "{params.hf_teacher_dir}" "{params.batch_size}" \
                    "{params.layer_num}" "{output}" "{params.hf_caching_dir}" >> {log} 2>&1'''

    rule minibatch_corpus_clustering_train:
        message: "Train a k-means model and cluster training data"
        log: f"{log_dir}/cluster_corpus_teacher{clustering_teacher_id}.log"
        conda: "envs/huggingface.yml"
        threads: 2
        resources: gpu=1
        input:
            embeddings=lambda wildcards: expand(f"{embedded_cluster_data_dir}/train/{{part}}_{embedded_source_postfix}",
                    part=find_parts(wildcards,checkpoints.split_corpus))
        output:
            model=f"{cluster_models_dir}/{kmeans_model_postfix}",
            labels=f"{labels_cluster_data_dir}/train/corpus/{cluster_labels_postfix}"
        params:
            num_clusters=num_clusters
        shell: '''python {third_party_dir}/domain_clusters/run_clustering_chunked.py \
                        --embedded-chunk-paths {input.embeddings} --out-file-model {output.model} \
                        --out-file-labels {output.labels} --n-clusters {params.num_clusters} \
                        --verbose 1 --random-state 42 >> {log} 2>&1'''

    rule corpus_clustering_dev_and_test:
        message: "Cluster dev and test data with pre-trained k-means model"
        log: f"{log_dir}/cluster_teacher{clustering_teacher_id}_{{dataset}}.log"
        conda: "envs/huggingface.yml"
        threads: 2
        resources: gpu=1
        # Wildcard constraints to make train clustering happen in a different rule
        # TODO: a less ugly way to do this?
        wildcard_constraints: dataset="|".join(["dev/devset"] + ["test/" + eval_set for eval_set in all_eval_datasets])
        input:
            embeddings=rules.extract_sentence_representations.output,
            # embeddings=rules.extract_sentence_representations_dev.output, #f"{cluster_data_dir}{{ens}}/train_{embedded_source_postfix}"
            model=rules.minibatch_corpus_clustering_train.output.model #f"{cluster_models_dir}{{ens}}/{kmeans_model_postfix}"
        output:
            labels=f"{labels_cluster_data_dir}/{{dataset}}/{cluster_labels_postfix}"
        params:
            num_clusters=num_clusters,
            num_initializations=10,
            max_iterations=300,
            batch_size=1024,
            max_no_improvement=10
        shell: '''python {third_party_dir}/domain_clusters/run_clustering.py \
                        --predict-with-model {input.model} \
                        --embedded-dataset-path {input.embeddings} \
                        --out-file-labels {output.labels} --n-clusters {params.num_clusters} \
                        --n_init {params.num_initializations} --max-iter {params.max_iterations} \
                        --batch-size {params.batch_size} --max-no-improvement-size {params.max_no_improvement} \
                        --verbose 1 --random-state 42 >> {log} 2>&1'''

    rule split_corpus_into_clusters:
        message: "Split corpus into discovered clusters"
        log: f"{log_dir}/split_into_clusters_{clustering_teacher_id}_{{dataset}}.log"
        conda: "envs/base.yml"
        threads: 4
        input:
            labels=f"{labels_cluster_data_dir}/{{dataset}}/{cluster_labels_postfix}",
            input=multiext(f"{orig_cluster_data_dir}/{{dataset}}", f".{src}.gz", f".{trg}.gz")
        output:
            expand(f"{split_cluster_data_dir}/{{dataset}}/{clustered_train_postfix}{{cluster_id}}.{{lang}}.gz",
                    cluster_id=list(range(num_clusters)), lang=[src, trg], allow_missing=True)
        params:
            input_prefix=f"{orig_cluster_data_dir}/{{dataset}}",
            num_clusters=num_clusters,
            cluster_dir=f"{split_cluster_data_dir}/{{dataset}}",
            output_prefix=f"{split_cluster_data_dir}/{{dataset}}/{clustered_train_postfix}"
        shell: '''bash pipeline/clusters/separate_clusters.sh \
                    "{params.input_prefix}" "{input.labels}" "{params.num_clusters}" \
                    "{params.cluster_dir}" "{params.output_prefix}" >> {log} 2>&1'''

if fine_tune_mode:
    ### fine-tune teacher to domains
    # TODO: get rid of at least some if-else's in this rule?
    rule finetune_teacher_to_domains:
        message: "Fine-tune teacher on each domain (corpus or cluster)"
        log: f"{log_dir}/finetune_teacher{{ens}}_to_domains_{{dataset}}.log"
        conda: "envs/base.yml"
        threads: gpus_num * 2
        resources: gpu=gpus_num
        group: 'teacher{ens}'
        input:
            dev_src=rules.create_held_out_sets.output.src_dev if fine_tune_mode == "corpus" \
                else f"{split_cluster_data_dir}/dev/devset/{clustered_train_postfix}{{dataset}}.{src}.gz",
            dev_trg=rules.create_held_out_sets.output.trg_dev if fine_tune_mode == "corpus" \
                else f"{split_cluster_data_dir}/dev/devset/{clustered_train_postfix}{{dataset}}.{trg}.gz",
            train_src=rules.create_held_out_sets.output.src_train if fine_tune_mode == "corpus" \
                else f"{split_cluster_data_dir}/train/corpus/{clustered_train_postfix}{{dataset}}.{src}.gz",
            train_trg=rules.create_held_out_sets.output.trg_train if fine_tune_mode == "corpus" \
                else f"{split_cluster_data_dir}/train/corpus/{clustered_train_postfix}{{dataset}}.{trg}.gz",
            bin=ancient(trainer),vocab=vocab_path,
            general_teacher=f'{final_teacher_dir}{{ens}}/{best_model}'
        output:
            model=f'{domain_finetuned_teacher_dir}{{ens}}/{{dataset}}/{best_model}'
        params:
            prefix_train=f"{held_out_corpus_prefix}/train/{{dataset}}" if fine_tune_mode == "corpus" \
                else f"{split_cluster_data_dir}/train/corpus/{clustered_train_postfix}{{dataset}}",
            prefix_test=f"{held_out_corpus_prefix}/dev/{{dataset}}" if fine_tune_mode == "corpus" \
                else f"{split_cluster_data_dir}/dev/devset/{clustered_train_postfix}{{dataset}}",
            dir=directory(f'{domain_finetuned_teacher_dir}{{ens}}/{{dataset}}'),
            args=get_args("training-teacher-finetuned")
        wildcard_constraints: ens="\d+", dataset="|".join(train_datasets) if fine_tune_mode == "corpus" else "\d+"
        shell: '''bash pipeline/train/train.sh \
                    teacher train {src} {trg} "{params.prefix_train}" "{params.prefix_test}" "{params.dir}" \
                    "{input.vocab}" --pretrained-model "{input.general_teacher}" {params.args} >> {log} 2>&1'''

### translation with teacher

# corpus

# Workflow without fine-tuning teacher models to parallel corpora
# Forward-translate with general teacher
if not fine_tune_mode or fine_tune_mode == "cluster":
    checkpoint split_corpus:
        message: "Splitting the corpus to translate"
        log: f"{log_dir}/split_corpus.log"
        conda: "envs/base.yml"
        threads: 1
        input: corpus_src=clean_corpus_src,corpus_trg=clean_corpus_trg
        output: directory(f"{translated}/corpus")
        shell: '''bash pipeline/translate/split-corpus.sh \
                    {input.corpus_src} {input.corpus_trg} {output} {split_length} >> {log} 2>&1'''

    rule translate_corpus:
        message: "Translating corpus with teacher"
        log: f"{log_dir}/translate_corpus/{{part}}.log"
        conda: "envs/base.yml"
        threads: gpus_num*2
        resources: gpu=gpus_num
        input:
            ancient(decoder),
            file=f'{translated}/corpus/file.{{part}}',
            vocab=vocab_path,
            teacher_models=expand(f"{final_teacher_dir}{{ens}}/{best_model}",ens=ensemble)
        output: f'{translated}/corpus/file.{{part}}.nbest'
        params: args=get_args('decoding-teacher')
        shell: '''bash pipeline/translate/translate-nbest.sh \
                    "{input.file}" "{input.vocab}" {input.teacher_models} {params.args} >> {log} 2>&1'''

    rule extract_best:
        message: "Extracting best translations for the corpus"
        log: f"{log_dir}/extract_best/{{part}}.log"
        conda: "envs/base.yml"
        threads: 1
        #group 'translate_corpus'
        input: nbest=f"{translated}/corpus/file.{{part}}.nbest", ref=f"{translated}/corpus/file.{{part}}.ref"
        output: f"{translated}/corpus/file.{{part}}.nbest.out"
        shell: 'python pipeline/translate/bestbleu.py -i {input.nbest} -r {input.ref} -m bleu -o {output} >> {log} 2>&1'

    rule collect_corpus:
        message: "Collecting translated corpus"
        log: f"{log_dir}/collect_corpus.log"
        conda: "envs/base.yml"
        threads: 4
        #group 'translate_corpus'
        input:
            lambda wildcards: expand(f"{translated}/corpus/file.{{part}}.nbest.out",
                part=find_parts(wildcards, checkpoints.split_corpus))
        output: f'{translated}/corpus.{trg}.gz'
        params: src_corpus=clean_corpus_src
        shell: 'bash pipeline/translate/collect.sh {translated}/corpus {output} {params.src_corpus} >> {log} 2>&1'

# Workflow with fine-tuning teachers to corpora or clusters
if fine_tune_mode:
    checkpoint split_corpus_domains:
        message: "Splitting the corpus to translate (clusters kept separate)"
        log: f"{log_dir}/split_corpus_domains_{{dataset}}.log"
        conda: "envs/base.yml"
        threads: 1
        # wildcard_constraints: dataset="\d+"
        input:
            corpus_src=f"{split_cluster_data_dir}/train/corpus/{clustered_train_postfix}{{dataset}}.{src}.gz" \
                if fine_tune_mode == "cluster" else f'{held_out_corpus_prefix}/train/{{dataset}}.{src}.gz',
            corpus_trg=f"{split_cluster_data_dir}/train/corpus/{clustered_train_postfix}{{dataset}}.{trg}.gz" \
                if fine_tune_mode == "cluster" else f'{held_out_corpus_prefix}/train/{{dataset}}.{trg}.gz'
        output:
            directory(f"{translated_domains}/corpus/parts/{{dataset}}")
        params:
            output_dir=f"{translated_domains}/corpus/parts/{{dataset}}"
        shell: '''bash pipeline/translate/split-corpus.sh \
                    {input.corpus_src} {input.corpus_trg} {params.output_dir} {split_length} >> {log} 2>&1'''

    rule translate_corpus_domains:
        message: "Translating corpora with domain teachers"
        log: f"{log_dir}/translate_corpus_domains/{{dataset}}_{{part}}.log"
        conda: "envs/base.yml"
        threads: gpus_num * 2
        resources: gpu=gpus_num
        input:
            ancient(decoder),
            file=f'{translated_domains}/corpus/parts/{{dataset}}/file.{{part}}',
            vocab=vocab_path,
            teacher_models=expand(f'{domain_finetuned_teacher_dir}{{ens}}/{{dataset}}/{best_model}',
                                    ens=ensemble, allow_missing=True)
        output: f'{translated_domains}/corpus/parts/{{dataset}}/file.{{part}}.nbest'
        params: args=get_args('decoding-teacher')
        wildcard_constraints: part="\d+"
        shell: '''bash pipeline/translate/translate-nbest.sh \
                    "{input.file}" "{input.vocab}" {input.teacher_models} {params.args} >> {log} 2>&1'''

    rule extract_best_domains:
        message: "Extracting best translations for the corpora (corpora kept separate)"
        log: f"{log_dir}/extract_best_domains/{{dataset}}/{{part}}.log"
        conda: "envs/base.yml"
        threads: 1
        # group: 'translate_corpus'
        input:
            nbest=f"{translated_domains}/corpus/parts/{{dataset}}/file.{{part}}.nbest",
            ref=f"{translated_domains}/corpus/parts/{{dataset}}/file.{{part}}.ref"
        output: f"{translated_domains}/corpus/parts/{{dataset}}/file.{{part}}.nbest.out"
        shell: 'python pipeline/translate/bestbleu.py -i {input.nbest} -r {input.ref} -m bleu -o {output} >> {log} 2>&1'

    rule collect_single_corpus_domains:
        message: "Collecting translated corpora separately"
        log: f"{log_dir}/collect_corpus_domains_{{dataset}}.log"
        conda: "envs/base.yml"
        threads: 4
        # group: 'translate_corpus'
        input:
            lambda wildcards: expand(f"{translated_domains}/corpus/parts/{{dataset}}/file.{{part}}.nbest.out",
                part=find_parts(wildcards,checkpoints.split_corpus_domains),
                # part=find_parts(wildcards,checkpoints.split_corpus_domains) if fine_tune_mode == "corpus" else find_parts(wildcards,checkpoints.split_corpus_clusters),
                allow_missing=True)
        output: f'{translated_domains}/corpus/collected/{{dataset}}.{trg}.gz'
        params: src_corpus=f'{held_out_corpus_prefix}/train/{{dataset}}.{src}.gz' if fine_tune_mode == "corpus" else f"{split_cluster_data_dir}/train/corpus/{clustered_train_postfix}{{dataset}}.{src}.gz"
        shell: '''bash pipeline/translate/collect.sh \
                 {translated_domains}/corpus/parts/{wildcards.dataset} \
                 {output} {params.src_corpus} >> {log} 2>&1'''

    rule collect_all_corpora_domains:
        message: "Collecting translated corpora into one"
        log: f"{log_dir}/collect_corpus_domains.log"
        conda: "envs/base.yml"
        threads: 4
        #group: 'translate_corpus'
        input:
            translations=expand(f'{translated_domains}/corpus/collected/{{dataset}}.{trg}.gz',
                dataset=train_datasets if fine_tune_mode == "corpus" else list(range(num_clusters))),
            src_corpus=clean_corpus_domain_ft_src if fine_tune_mode == "corpus" else clean_corpus_src
        output: f'{translated_domains}/corpus.{trg}.gz'
        params:
            src_corpus=clean_corpus_domain_ft_src if fine_tune_mode == "corpus" else clean_corpus_src
        shell: '''bash pipeline/translate/collect-corpora.sh \
                         {output} {params.src_corpus} {input.translations} >> {log} 2>&1'''


# mono

checkpoint split_mono_src:
    message: "Splitting monolingual src dataset"
    log: f"{log_dir}/split_mono_src.log"
    conda: "envs/base.yml"
    threads: 1
    input: corpora=f"{clean}/mono.{src}.gz", bin=ancient(deduper)
    output: directory(f'{translated}/mono_src')
    shell: 'bash pipeline/translate/split-mono.sh {input.corpora} {output} {split_length} >> {log} 2>&1'

rule translate_mono_src:
    message: "Translating monolingual src dataset with teacher"
    log: f"{log_dir}/translate_mono_src/{{part}}.log"
    conda: "envs/base.yml"
    threads: gpus_num*2
    resources: gpu=gpus_num
    input:
        file=f'{translated}/mono_src/file.{{part}}',vocab=vocab_path,
        teacher_models=expand(f"{final_teacher_dir}{{ens}}/{best_model}",ens=ensemble),
        bin=ancient(decoder)
    output: f'{translated}/mono_src/file.{{part}}.out'
    params: args=get_args('decoding-teacher')
    shell: '''bash pipeline/translate/translate.sh "{input.file}" "{input.vocab}" {input.teacher_models} \
              {params.args} >> {log} 2>&1'''

rule collect_mono_src:
    message: "Collecting translated mono src dataset"
    log: f"{log_dir}/collect_mono_src.log"
    conda: "envs/base.yml"
    threads: 4
    #group 'mono_src'
    input:
       lambda wildcards: expand(f"{translated}/mono_src/file.{{part}}.out",
           part=find_parts(wildcards, checkpoints.split_mono_src))
    output: f'{translated}/mono.{trg}.gz'
    params: src_mono=f"{clean}/mono.{src}.gz",dir=f'{translated}/mono_src'
    shell: 'bash pipeline/translate/collect.sh "{params.dir}" "{output}" "{params.src_mono}" >> {log} 2>&1'

# merge

rule merge_translated:
    message: "Merging translated datasets"
    log: f"{log_dir}/merge_translated.log"
    conda: "envs/base.yml"
    threads: 4
    #group 'mono_src'
    input:
        src1=clean_corpus_src if fine_tune_mode != "corpus" else clean_corpus_domain_ft_src,
        src2=f"{clean}/mono.{src}.gz",
        trg1=rules.collect_corpus.output if not fine_tune_mode else rules.collect_all_corpora_domains.output,
        trg2=rules.collect_mono_src.output,
        bin=ancient(deduper)
    output: res_src=f'{merged}/corpus.{src}.gz',res_trg=f'{merged}/corpus.{trg}.gz'
    shell: '''bash pipeline/translate/merge-corpus.sh \
                "{input.src1}" "{input.src2}" "{input.trg1}" "{input.trg2}" "{output.res_src}" "{output.res_trg}" \
                  >> {log} 2>&1'''

# train student

rule score:
    message: "Scoring"
    log: f"{log_dir}/score.log"
    conda: "envs/base.yml"
    threads: gpus_num*2
    resources: gpu=gpus_num
    input:
        ancient(scorer),
        model=f'{backward_dir}/{best_model}', vocab=vocab_path,
        src_corpus=rules.merge_translated.output.res_src, trg_corpus=rules.merge_translated.output.res_trg
    output: f"{filtered}/scores.txt"
    params: input_prefix=f'{merged}/corpus'
    shell: '''bash pipeline/cefilter/score.sh \
                "{input.model}" "{input.vocab}" "{params.input_prefix}" "{output}" >> {log} 2>&1'''

rule ce_filter:
    message: "Cross entropy filtering"
    log: f"{log_dir}/ce_filter.log"
    conda: "envs/base.yml"
    threads: workflow.cores
    resources: mem_mb=workflow.cores*5000
    input:
        src_corpus=rules.merge_translated.output.res_src,trg_corpus=rules.merge_translated.output.res_trg,
        scores=rules.score.output
    output: src_corpus=f"{filtered}/corpus.{src}.gz",trg_corpus=f"{filtered}/corpus.{trg}.gz"
    params: input_prefix=f'{merged}/corpus',output_prefix=f'{filtered}/corpus'
    shell: '''bash pipeline/cefilter/ce-filter.sh \
                "{params.input_prefix}" "{params.output_prefix}" "{input.scores}" >> {log} 2>&1'''

rule alignments:
    message: 'Training word alignment and lexical shortlists'
    log: f"{log_dir}/alignments.log"
    conda: "envs/base.yml"
    threads: workflow.cores
    input:
        ancient(spm_encoder), ancient(spm_exporter),
        src_corpus=rules.ce_filter.output.src_corpus,trg_corpus=rules.ce_filter.output.trg_corpus,
        vocab=vocab_path,
        fast_align=ancient(rules.fast_align.output.fast_align), atools=ancient(rules.fast_align.output.atools),
        extract_lex=ancient(rules.extract_lex.output)
    output: alignment=f'{align_dir}/corpus.aln.gz',shortlist=f'{align_dir}/lex.s2t.pruned.gz'
    params: input_prefix=f'{filtered}/corpus'
    shell: '''bash pipeline/alignment/generate-alignment-and-shortlist.sh \
                "{params.input_prefix}" "{input.vocab}" "{align_dir}" {threads} >> {log} 2>&1'''

rule train_student:
    message: "Training student"
    log: f"{log_dir}/train_student.log"
    conda: "envs/base.yml"
    threads: gpus_num*2
    resources: gpu=gpus_num
    #group 'student'
    input:
        rules.merge_devset.output, ancient(trainer),
        train_src=rules.ce_filter.output.src_corpus, train_trg=rules.ce_filter.output.trg_corpus,
        alignments=rules.alignments.output.alignment,
        vocab=vocab_path
    output: model=f'{student_dir}/{best_model}'
    params: prefix_train=rules.ce_filter.params.output_prefix,prefix_test=f"{original}/devset",
            args=get_args("training-student")
    shell: '''bash pipeline/train/train-student.sh \
                "{input.alignments}" student train {src} {trg} "{params.prefix_train}" "{params.prefix_test}" \
                "{student_dir}" "{input.vocab}" {params.args} >> {log} 2>&1'''

# quantize

rule finetune_student:
    message: "Fine-tuning student"
    log: f"{log_dir}/finetune_student.log"
    conda: "envs/base.yml"
    threads: gpus_num*2
    resources: gpu=gpus_num
    #group 'student-finetuned'
    input:
        rules.merge_devset.output, ancient(trainer),
        train_src=rules.ce_filter.output.src_corpus, train_trg=rules.ce_filter.output.trg_corpus,
        alignments=rules.alignments.output.alignment, student_model=rules.train_student.output.model,
        vocab=vocab_path
    output: model=f'{student_finetuned_dir}/{best_model}'
    params: prefix_train=rules.ce_filter.params.output_prefix,prefix_test=f"{original}/devset",
            args=get_args("training-student-finetuned")
    shell: '''bash pipeline/train/train-student.sh \
                "{input.alignments}" student finetune {src} {trg} "{params.prefix_train}" "{params.prefix_test}" \
                "{student_finetuned_dir}" "{input.vocab}" --pretrained-model "{input.student_model}" {params.args} >> {log} 2>&1'''

rule quantize:
    message: "Quantization"
    log: f"{log_dir}/quntize.log"
    conda: "envs/base.yml"
    threads: 1
    input:
        ancient(bmt_decoder), ancient(bmt_converter),
        shortlist=rules.alignments.output.shortlist, model=rules.finetune_student.output.model,
        vocab=vocab_path, devset=f"{original}/devset.{src}.gz"
    output: model=f'{speed_dir}/model.intgemm.alphas.bin'
    shell: '''bash pipeline/quantize/quantize.sh \
                "{input.model}" "{input.vocab}" "{input.shortlist}" "{input.devset}" "{speed_dir}" >> {log} 2>&1'''

rule export:
    message: "Exporting models"
    log: f"{log_dir}/export.log"
    conda: "envs/base.yml"
    #group 'export'
    threads: 1
    input:
        model=rules.quantize.output.model,shortlist=rules.alignments.output.shortlist,
        vocab=vocab_path,marian=bmt_converter
    output:
        model=f'{exported_dir}/model.{src}{trg}.intgemm.alphas.bin.gz',
        shortlist=f'{exported_dir}/lex.50.50.{src}{trg}.s2t.bin.gz',
        vocab=f'{exported_dir}/vocab.{src}{trg}.spm.gz'
    shell:
        'bash pipeline/quantize/export.sh "{speed_dir}" "{input.shortlist}" "{input.vocab}" "{exported_dir}" >> {log} 2>&1'

### evaluation

rule evaluate:
    message: "Evaluating a model"
    log: f"{log_dir}/eval/eval_{{model}}_{{dataset}}.log"
    conda: "envs/base.yml"
    threads: gpus_num * 2
    resources: gpu=gpus_num
    #group '{model}'
    priority: 50
    wildcard_constraints:
        model="[\w-]+"
    input:
        ancient(decoder),
        data=multiext(f'{eval_data_dir}/{{dataset}}',f".{src}.gz",f".{trg}.gz"),
        models=lambda wildcards: f'{models_dir}/{wildcards.model}/{best_model}'
                                    if wildcards.model != 'teacher-ensemble'
                                    else [f'{final_teacher_dir}{ens}/{best_model}' for ens in ensemble]
    output:
        report(f'{eval_res_dir}/{{model}}/{{dataset}}.metrics',
            category='evaluation', subcategory='{model}', caption='reports/evaluation.rst')
    params:
        dataset_prefix=f'{eval_data_dir}/{{dataset}}',
        res_prefix=f'{eval_res_dir}/{{model}}/{{dataset}}',
        src_lng=lambda wildcards: src if wildcards.model != 'backward' else trg,
        trg_lng=lambda wildcards: trg if wildcards.model != 'backward' else src,
        decoder_config=lambda wildcards: f'{models_dir}/{wildcards.model}/{best_model}.decoder.yml'
                            if wildcards.model != 'teacher-ensemble'
                            else f'{final_teacher_dir}0/{best_model}.decoder.yml'
    shell: '''bash pipeline/eval/eval-gpu.sh "{params.res_prefix}" "{params.dataset_prefix}" \
             {params.src_lng} {params.trg_lng} "{params.decoder_config}" {input.models} >> {log} 2>&1'''

rule eval_quantized:
    message: "Evaluating quantized student model"
    log: f"{log_dir}/eval_quantized_{{dataset}}.log"
    conda: "envs/base.yml"
    #group 'export'
    threads: 1
    priority: 50
    input:
        ancient(bmt_decoder),
        data=multiext(f'{eval_data_dir}/{{dataset}}',f".{src}.gz",f".{trg}.gz"),
        model=rules.quantize.output.model,
        shortlist=rules.alignments.output.shortlist,
        vocab=vocab_path
    output:
        report(f'{eval_speed_dir}/{{dataset}}.metrics', category='evaluation',
            subcategory='quantized', caption='reports/evaluation.rst')
    params:
        dataset_prefix=f'{eval_data_dir}/{{dataset}}',
        res_prefix=f'{eval_speed_dir}/{{dataset}}',
        decoder_config='../quantize/decoder.yml'
    shell: '''bash pipeline/eval/eval-quantized.sh "{input.model}" "{input.shortlist}" "{params.dataset_prefix}" \
            "{input.vocab}" "{params.res_prefix}" "{params.decoder_config}" >> {log} 2>&1'''

if fine_tune_mode == "corpus":
    rule eval_teachers_finetuned_to_corpus:
        message: "Evaluating a model"
        log: f"{log_dir}/eval/eval_teachers_finetuned_to_corpus_{{model}}_{{train_dataset}}_{{dataset}}.log"
        conda: "envs/base.yml"
        threads: gpus_num * 2
        resources: gpu=gpus_num
        #group '{model}'
        priority: 50
        wildcard_constraints:
            model="[\w-]+",
            dataset="|".join(all_eval_datasets)
        input:
            ancient(decoder),
            data=multiext(f'{eval_data_dir}/{{dataset}}',f".{src}.gz",f".{trg}.gz"),
            models=lambda wildcards: f'{models_dir}/{wildcards.model}/{wildcards.train_dataset}/{best_model}'
                                        if wildcards.model != 'teacher-domain-ft-ensemble'
                                        else [f'{domain_finetuned_teacher_dir}{ens}/{wildcards.train_dataset}/{best_model}'
                                              for ens in ensemble]
        output:
            report(f'{eval_corpus_ft_teachers_dir}/{{model}}/{{train_dataset}}/{{dataset}}.metrics',
                category='evaluation',subcategory='{model}',caption='reports/evaluation.rst')
        params:
            dataset_prefix=f'{eval_data_dir}/{{dataset}}',
            res_prefix=f'{eval_corpus_ft_teachers_dir}/{{model}}/{{train_dataset}}/{{dataset}}',
            src_lng=src,
            trg_lng=trg,
            decoder_config=lambda wildcards: f'{models_dir}/{wildcards.model}/{wildcards.train_dataset}/{best_model}.decoder.yml'
                            if wildcards.model != 'teacher-domain-ft-ensemble'
                            else f'{domain_finetuned_teacher_dir}0/{wildcards.train_dataset}/{best_model}.decoder.yml'
        shell: '''bash pipeline/eval/eval-gpu.sh "{params.res_prefix}" "{params.dataset_prefix}" \
                 {params.src_lng} {params.trg_lng} "{params.decoder_config}" {input.models} >> {log} 2>&1'''

if fine_tune_mode == "cluster":
    rule translate_with_teachers_finetuned_to_cluster:
        message: "Evaluating a model"
        log: f"{log_dir}/eval/transl_teachers_finetuned_to_cluster_{{model}}_{{cluster_id}}_{{dataset}}.log"
        conda: "envs/base.yml"
        threads: gpus_num * 2
        resources: gpu=gpus_num
        #group '{model}'
        priority: 50
        wildcard_constraints:
            model="[\w-]+",
            dataset="|".join(all_eval_datasets),
            cluster_id="\d+"
        input:
            ancient(decoder),
            data=multiext(f"{split_cluster_data_dir}/test/{{dataset}}/{clustered_train_postfix}{{cluster_id}}",
                    f".{src}.gz", f".{trg}.gz"),
            models=lambda wildcards: f'{models_dir}/{wildcards.model}/{wildcards.cluster_id}/{best_model}'
                                        if wildcards.model != 'teacher-domain-ft-ensemble'
                                        else [f'{domain_finetuned_teacher_dir}{ens}/{wildcards.cluster_id}/{best_model}'
                                              for ens in ensemble]
        output:
            f"{eval_corpus_ft_teachers_dir}/{{model}}/{{cluster_id}}/{{dataset}}/{{cluster_id}}.{src}",
            f"{eval_corpus_ft_teachers_dir}/{{model}}/{{cluster_id}}/{{dataset}}/{{cluster_id}}.{trg}"
        params:
            dataset_prefix=f"{split_cluster_data_dir}/test/{{dataset}}/{clustered_train_postfix}{{cluster_id}}",
            res_prefix=f'{eval_corpus_ft_teachers_dir}/{{model}}/{{cluster_id}}/{{dataset}}/{{cluster_id}}',
            src_lng=src,
            trg_lng=trg,
            decoder_config=lambda wildcards: f'{models_dir}/{wildcards.model}/{wildcards.cluster_id}/{best_model}.decoder.yml'
                            if wildcards.model != 'teacher-domain-ft-ensemble'
                            else f'{domain_finetuned_teacher_dir}0/{wildcards.cluster_id}/{best_model}.decoder.yml'
        shell: '''bash pipeline/eval/translate-clustered-subsets-gpu.sh "{params.res_prefix}" "{params.dataset_prefix}" \
                 {params.src_lng} {params.trg_lng} "{params.decoder_config}" {input.models} >> {log} 2>&1'''

    rule eval_teachers_finetuned_to_cluster:
        message: "Evaluating a model"
        log: f"{log_dir}/eval/eval_teachers_finetuned_to_cluster_{{model}}_{{dataset}}.log"
        conda: "envs/base.yml"
        threads: 4
        #group '{model}'
        priority: 50
        wildcard_constraints:
            model="[\w-]+",
            dataset="|".join(all_eval_datasets),
            cluster_id="\d+"
        input:
            src_data=expand(f"{eval_corpus_ft_teachers_dir}/{{model}}/{{cluster_id}}/{{dataset}}/{{cluster_id}}.{src}",
                    cluster_id=list(range(num_clusters)), allow_missing=True),
            trg_data=expand(f"{eval_corpus_ft_teachers_dir}/{{model}}/{{cluster_id}}/{{dataset}}/{{cluster_id}}.{trg}",
                    cluster_id=list(range(num_clusters)), allow_missing=True),
            orig_source=f"{orig_cluster_data_dir}/test/{{dataset}}.{src}.gz",
            orig_ref=f"{orig_cluster_data_dir}/test/{{dataset}}.{trg}.gz"
        output:
            report(f'{eval_corpus_ft_teachers_dir}/{{model}}/{{dataset}}.metrics',
                category='evaluation',subcategory='{model}',caption='reports/evaluation.rst')
        params:
            input_prefixes=expand(f"{eval_corpus_ft_teachers_dir}/{{model}}/{{cluster_id}}/{{dataset}}/{{cluster_id}}",
                    cluster_id=list(range(num_clusters)), allow_missing=True),
            src_lng=src,
            trg_lng=trg,
            res_prefix=f'{eval_corpus_ft_teachers_dir}/{{model}}/{{dataset}}'
        shell: '''bash pipeline/eval/merge-and-eval-clustered.sh "{params.res_prefix}" "{input.orig_source}" \
                 "{input.orig_ref}" {params.src_lng} {params.trg_lng} {params.input_prefixes} >> {log} 2>&1'''

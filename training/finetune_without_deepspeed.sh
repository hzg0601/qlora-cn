# set -x会在执行每一行 shell 脚本时，把执行的内容输出来。它可以让你看到当前执行的情况，里面涉及的变量也会被替换成实际的值。

# set -e会在执行出错时结束程序，就像其他语言中的“抛出异常”一样。（准确说，不是所有出错的时候都会结束程序，见下面的注）

# 注：set -e结束程序的条件比较复杂，在man bash里面，足足用了一段话描述各种情景。大多数执行都会在出错时退出，除非 shell 命令位于以下情况：

# 一个 pipeline 的非结尾部分，比如 error | ok

# 一个组合语句的非结尾部分，比如 ok && error || other

# 一连串语句的非结尾部分，比如 error; ok

# 位于判断语句内，包括 test、if、 while 等等。

# 这两个组合在一起用，可以在 debug 的时候替你节省许多时间。

set -e # -x

run_id=$(date +%s)
echo "RUN ID: $run_ts"

echo "START TIME: $(date)"


ROOT_DIR_BASE="."
OUTPUT_PATH=$ROOT_DIR_BASE/output_$run_id

mkdir -p $OUTPUT_PATH

input_log="qlora_logs.log"
[ -f $input_log ] && echo "input_log $input_log found" || touch $input_log

# command 命令需要交互式输入：如果 command 命令需要从终端接收输入，例如密码或交互式菜单，那么无法在脚本模式下运行nohup命令。
wandb login

export WANDB_PROJECT="guanaco-33b-tuning"
# wandb.errors.CommError: Run initialization has timed out after 60.0 sec. 
# 上传wandb离线数据的方法
# wandb sync ./wandb/offline-run-*******_******-******
export WANDB_MODE="offline"
# based on test in ./test_cn_dataset_lenghts.py :

#source len @qt0.8: 188.0
#target len @qt0.8: 222.0
#source len @qt0.85: 228.0
#target len @qt0.85: 267.0
#source len @qt0.9: 297.0
#target len @qt0.9: 342.0
#source len @qt0.95: 396.0
#target len @qt0.95: 491.0
#source len @qt0.98: 515.0
#target len @qt0.98: 670.2800000000279

# nohup的重定向不起作用的情况，因为要使用wandb，故无法重定向
# 如果 command 命令需要交互式终端才能正常运行，那么nohup命令将无法满足这个要求，因此会忽略输入并将输出附加到 "nohup.out" 文件中。
# command 命令需要与用户交互：如果 command 命令需要与用户交互，例如向用户显示消息或询问用户是否继续执行操作，那么无法在不与终端关联的情况下运行该命令。
# 如果command 命令需要特定的终端设备：如果 command 命令需要特定的终端设备，例如串口、并口或图形终端，那么可能无法在脚本模式下运行该命令。
export CUDA_VISIBLE_DEVICE=1
nohup python -u qlora.py \
    --dataset="Belle_0.5M" \
    # --dataset_format="Belle_0.5M" `#alpaca-clean has similar format to chinese training dataset` \
    --learning_rate 0.0001 `# QLoRA paper appendix B Table 9 `\
    --per_device_train_batch_size 1 `# fix for fitting mem `\
    --gradient_accumulation_steps 16 `# QLoRA paper appendix B Table 9  `\
    --max_steps 10000 `# QLoRA paper appendix B Table 9, follow paper setting even though cn data is 690k much bigger than OASST1 9k, batch size considering accum`\
    --model_name_or_path huggyllama/llama-7b \
    --source_max_len 512  `# default setting in code, cn model 2048 too long  `\
    --target_max_len 512 `# follow QLoRA paper appendix B Table 9 `\
    --eval_dataset_size 1 `# mainly for testing, no need to be big` \
    --do_eval \
    --evaluation_strategy "steps" \
    --eval_steps 200 `# 10 for debug mode only, 200 for training`  \
    --output_dir $OUTPUT_PATH \
    --report_to 'wandb' \ 
    --sample_generate `# test sample generation every once a while`  \
    --save_steps 200 `# 20 for debug mode only, 200 for training` \
    --do_mmlu_eval `#do mmlu eval` \
    <qlora_logs.log >huggyllama_7b_without_ds.log 2>&1 &

#    --debug_mode `# only set when it's debug mode` \
# 如果出现 nohup: ignoring input and appending output to ‘nohup.out’，
# 则表明命令里使用了标准输入（stdin）而不是重定向输入
# 此时需要将标准输入重定向到文件中，即<qlora_logs.log,前提是qlora_logs.log必须是已经存在的文件
# 后续可以看一下怎么调用wandb

# 如果上述方法仍不起作用，则表明代码中包含了交互式命令。
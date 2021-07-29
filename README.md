# grads_ctl

Bash scripts to read GrADS control files for analysis.

## grads_time2t.sh
### Synopsis
```
grads_time2t.sh ''control-fname'' ''grads-time'' [''option'']
```
### Description
TODO

### Options

| Argument | Description |
| ------------- | ------------- |
| ''control-fname'' | Control file name |
| ''grads-time''    | GrADS-style time or YYYYMMDD, for example, "01jan2004"、"20040101". |
| ''option''        | -gt, -ge, -lf, or -le. |

### Return
''grads-time'' に最も近いタイムステップ番号。

### '''option'''について
出力されるタイムステップに相当する時刻 T と ''grads-time'' との関係を指定します。例えば -gt は T > ''grads-time'' となるように T を出力します。

NICAM では時刻の下限を得る場合に -gt、上限を得る場合に -le を指定するとデータ境界の問題が起きづらい。


## grads_t2time.sh
```
grads_t2time.sh ''control-fname'' ''grads-t''
```
### 引数

| 引数 | 説明 |
| ------------- | ------------- |
| ''control-fname'' |コントロールファイル名 |
| ''grads-t''       |タイムステップ |

### 出力
''grads-t'' に最も近いGrADS形式の時刻。

## grads_get_data.sh

## grads_ctl.pl
```
grads_ctl.pl
```
コントロールファイルを解析・修正。

## grads_exist_data.sh


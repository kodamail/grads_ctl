# grads_ctl

## 全般
GrADSのコントロールファイルを読み込んで各種処理を行うbashスクリプト群。

### grads_time2t.sh
```
grads_time2t.sh ''control-fname'' ''grads-time'' [''option'']
```
#### 引数

| 引数 | 説明 |
| ------------- | ------------- |
| ''control-fname'' | コントロールファイル名 |
| ''grads-time''    | GrADS形式の時刻又はYYYYMMDD。例えば "01jan2004"、"20040101" 等。 |
| ''option''        | -gt, -ge, -lf, 又は -le。 |

!!!出力
''grads-time'' に最も近いタイムステップ番号。
#### '''option'''について
出力されるタイムステップに相当する時刻 T と ''grads-time'' との関係を指定します。例えば -gt は T > ''grads-time'' となるように T を出力します。

NICAM では時刻の下限を得る場合に -gt、上限を得る場合に -le を指定するとデータ境界の問題が起きづらい。


### grads_t2time.sh
```
grads_t2time.sh ''control-fname'' ''grads-t''
```
#### 引数

| 引数 | 説明 |
| ------------- | ------------- |
| ''control-fname'' |コントロールファイル名 |
| ''grads-t''       |タイムステップ |

#### 出力
''grads-t'' に最も近いGrADS形式の時刻。

### grads_get_data.sh

### grads_ctl.pl
```
grads_ctl.pl
```
コントロールファイルを解析・修正。

### grads_exist_data.sh


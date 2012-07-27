
package MT::Plugin::GroongaSearch::L10N::ja;

use strict;
use utf8;
use base 'MT::Plugin::GroongaSearch::L10N::en_us';
use vars qw( %Lexicon );

## The following is the translation table.

%Lexicon = (
    'Provides fast searching with groonga.'
        => 'Groongaによる高速検索を提供します。',
    'Relative path from [_1] or absolute path starts with /.'
        => '[_1]からの相対パスか/から始まる絶対パス',
    'Resync Groonga Search' => 'Groonga検索の再同期',
    'Start Resync' => '再同期を開始',
    '[_1] object(s)' => '[_1]件のオブジェクト',
    'All resynchronizations completed' => 'すべての再同期が完了しました',
    'Retry Resync' => '再同期しなおす',
    'Resync maybe processing by another. Wait a minute and reload until disappeared this warning.'
        => '再同期が他の画面ですでに実行されている可能性があります。この警告が消えるまで、時間をおいてから再読込してください。',
    'But if no one another processes resync or this warning retain for long time, resync forcely.'
        => 'ただし、再同期が実行中でないか、長時間この警告が消えない場合は強制的に再同期してください。',
    'Another resync session started.' => '他の画面で再同期が開始されました',
);

1;

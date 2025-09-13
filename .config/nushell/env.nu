# env.nu

$env.config.edit_mode = 'vi'
$env.config.buffer_editor = 'helix'
$env.config.cursor_shape.vi_insert = "line"
$env.config.cursor_shape.vi_normal = "block"
$env.config.show_banner = false
$env.CARAPACE_BRIDGES = 'zsh,fish,bash,inshellisense'

$env.PATH ++= [
    '~/.cargo/bin',
    '~/.local/bin',
    '~/.config/composer/vendor/bin',
    '~/.local/share/nvim/mason/bin',
    '/opt/homebrew/bin',
    '/opt/homebrew/opt/m4/bin',
    '/opt/homebrew/opt/llvm/bin',
]

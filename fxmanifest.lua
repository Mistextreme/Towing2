fx_version 'cerulean'
game 'gta5'

author 'Professional Development Team'
description 'Advanced Flatbed & Tow System with Dynamic Configuration'
version '2.0.0'

lua54 'yes'

shared_scripts {
    '@es_extended/imports.lua',
    'config.lua'
}

client_scripts {
    'client/utils.lua',
    'client/editor.lua',
    'client/ramps.lua',
    'client/winch.lua',
    'client/attach.lua',
    'client/main.lua'
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua'
}

dependencies {
    'es_extended',
    'oxmysql'
}
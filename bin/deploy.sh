set -eux
rsync -rv public/ tylerkontra.com:~/tylerkontra.com/public/
ssh tylerkontra.com "sudo cp -r tylerkontra.com/public/* /var/www/tylerkontra.com/"
set -e

sudo -u ec2-user -i <<'EOP'
###############################
#
# INSTALL THEIA IDE 
#
###############################
echo INSTALLING THEIA
CONFIG_DIR=${HOME}/lifecycle-config/config
EC2_HOME=/home/ec2-user
mkdir ${EC2_HOME}/theia && cd ${EC2_HOME}/theia

### begin by installing NVM, NodeJS v12, and Yarn

curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.1/install.sh | bash
source ~/.nvm/nvm.sh
nvm install 12
nvm use 12
npm install -g yarn

# for reference, see: https://github.com/theia-ide/theia-apps/blob/master/theia-python-docker/latest.package.json
cp ${CONFIG_DIR}/package.json ${EC2_HOME}/theia/
nohup yarn & 

#####################################
### CONFIGURE THEIA IDE
#####################################
THEIA_PATH=$PATH
mkdir ${EC2_HOME}/.theia
mkdir -p ~/SageMaker/.theia
cp ${CONFIG_DIR}/launch.json ${EC2_HOME}/.theia/
cp ${CONFIG_DIR}/settings.json ${EC2_HOME}/.theia/

###############################
#
# UPDATE JUPYTER AND EXTENSIONS
#
###############################
echo CONFIGURING NOTEBOOK SERVER
source ~/anaconda3/bin/activate JupyterSystemEnv

echo UPGRADING JUPYTERLAB
# UPGRADE JUPYTERLAB, VOILA, IPYWIDGETS, S3 BROWSER, PYTHON LANGUAGE SERVER, AND SERVER PROXY
pip install --upgrade pip
pip install -U jupyterlab 
pip install -U voila ipywidgets \
    jupyterlab-s3-browser python-language-server[all]  \
    python-jsonrpc-server jupyter-lsp \
    jupyter-server-proxy pylint autopep8 yapf pyflakes pycodestyle
jupyter labextension update --all

## CONFIGURE JUPYTER PROXY TO MAP TO THE THEIA IDE
JUPYTER_ENV=~/anaconda3/envs/JupyterSystemEnv

cat >>${JUPYTER_ENV}/etc/jupyter/jupyter_notebook_config.py <<EOC
c.ServerProxy.servers = {
  'theia': {
    'command': ['yarn', '--cwd', '/home/ec2-user/theia', 'start', '/home/ec2-user/SageMaker', '--port', '{port}'],
    'environment': {'PATH': '${THEIA_PATH}'},
    'absolute_url': False,
    'timeout': 30
  }
}
EOC

echo INSTALLING LAB EXTENSIONS
jupyter labextension install @jupyter-voila/jupyterlab-preview jupyterlab-s3-browser @krassowski/jupyterlab-lsp @jupyterlab/server-proxy
jupyter serverextension enable --py --sys-prefix jupyter_server_proxy

# CONFIGURE JUPYTER LAB DARK MODE
echo CONFIGURE LAB UI
mkdir -p ~/.jupyter/lab/user-settings/\@jupyterlab/apputils-extension
cat >~/.jupyter/lab/user-settings/\@jupyterlab/apputils-extension/themes.jupyterlab-settings <<EOF
{
    "theme": "JupyterLab Dark"
}
EOF

source ~/anaconda3/bin/deactivate 
echo NOTEBOOK CONFIGURATION COMPLETE 

EOP

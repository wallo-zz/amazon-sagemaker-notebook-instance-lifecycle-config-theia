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

#####################################
### INTEGRATE THEIA IDE WITH JUPYTER PROXY
#####################################
cat >>/home/ec2-user/.jupyter/jupyter_notebook_config.py <<EOC
c.ServerProxy.servers = {
  'theia': {
    'command': ['yarn', '--cwd', '/home/ec2-user/theia', 'start', '/home/ec2-user/SageMaker', '--port', '{port}'],
    'environment': {'PATH': '${THEIA_PATH}'},
    'absolute_url': False,
    'timeout': 30
  }
}
EOC

source /home/ec2-user/anaconda3/bin/activate JupyterSystemEnv
pip install \
    python-language-server[all]  \
    jupyter-lsp \
    pylint \
    autopep8 \
    yapf \
    pyflakes \
    pycodestyle

echo INSTALLING LAB EXTENSIONS
jupyter labextension install \
    @krassowski/jupyterlab-lsp \
    @jupyterlab/server-proxy

# CONFIGURE JUPYTER LAB DARK MODE
echo CONFIGURE LAB UI
mkdir -p ~/.jupyter/lab/user-settings/\@jupyterlab/apputils-extension
cat >~/.jupyter/lab/user-settings/\@jupyterlab/apputils-extension/themes.jupyterlab-settings <<EOF
{
    "theme": "JupyterLab Dark"
}
EOF

conda deactivate 
echo NOTEBOOK CONFIGURATION COMPLETE 

EOP

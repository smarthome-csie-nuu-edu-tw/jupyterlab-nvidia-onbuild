# Copyright (c) Jupyter Development Team.
# Distributed under the terms of the Modified BSD License.

FROM nvidia/cuda:10.0-cudnn7-devel
LABEL maintainer="ziyi-bear <m0724001@gm.nuu.edu.tw>"
USER root

# ENV #######################################################################################################
# APT套件安裝環境設定
# OSError: MATLAB Engine for Python supports Python version 2.7, 3.5 and 3.6 -> MINICONDA_VERSION 4.3.31
# 
#############################################################################################################
ENV DEBIAN_FRONTEND noninteractive
# 主要鏡像環境設定
ENV CONDA_DIR=/opt/conda \
    SHELL=/bin/bash \
    NB_USER=jovyan \
    NB_UID=1000 \
    NB_GID=100 \
    LC_ALL=en_US.UTF-8 \
    LANG=en_US.UTF-8 \
    LANGUAGE=en_US.UTF-8
ENV PATH=$CONDA_DIR/bin:$PATH \
    HOME=/home/$NB_USER
# MINICONDA_VERSION 環境設定
ENV MINICONDA_VERSION 4.3.31
ENV MINICONDA_CHECKSUM 7fe70b214bee1143e3e3f0467b71453c
# Tensorflow Allowing GPU memory growth
ENV TF_FORCE_GPU_ALLOW_GROWTH true

# locale-gen ##############################################################
# 設定區域語系需在APT安裝前完成否則APT安裝會出錯
#
###########################################################################
USER root
RUN apt-get update && apt-get -yq dist-upgrade && \
    apt-get upgrade -y \
    && apt-get install -yq --no-install-recommends \
    locales

RUN locale-gen --lang en_US.UTF-8 && \
    locale-gen --lang zh_TW.UTF-8 && \
    dpkg-reconfigure locales

# APT ########################################
# 基本系統套件
#
##############################################
USER root
RUN apt-get update && apt-get -yq dist-upgrade && \
    apt-get upgrade -y \
    && apt-get install -yq --no-install-recommends \
    apt-utils autoconf automake \
    bzip2 build-essential \
    ca-certificates cmake clang \
    default-jre \
    emacs \
    fonts-liberation ffmpeg \
    git graphviz gir1.2-goocanvas-2.0 \
    php7.2 php7.2-dev php-zmq \
    inkscape \
    jed \
    libsm6 libxext-dev libxrender1 lmodern \
    libreadline-dev libopencv-dev libzmq3-dev libtool \
    libssl-dev libglu1-mesa-dev \
    make mesa-common-dev mercurial \
    nano \
    openssh-client \
    pandoc python-dev python-pydot python-pydot-ng pkg-config pv protobuf-compiler python-pil python-lxml python-tk python-gi-cairo \
    python-gi python-pygraphviz \
    rename \
    sudo \
    texlive-fonts-extra texlive-fonts-recommended texlive-generic-recommended texlive-latex-base texlive-latex-extra texlive-xetex \
    unrar unzip \
    vim \
    wget \
    zip

# Fonts #######################
# 字型添加
#
###############################
USER root
RUN apt-get update && \
    apt-get install -yq --no-install-recommends fonts-moe-standard-song fonts-moe-standard-kai fonts-cns11643-sung fonts-cns11643-kai fonts-arphic-ukai \
    fonts-arphic-uming fonts-arphic-bkai00mp fonts-arphic-bsmi00lp fonts-arphic-gbsn00lp fonts-arphic-gkai00mp fonts-cwtex-ming fonts-cwtex-kai fonts-cwtex-heib \
    fonts-cwtex-yen fonts-cwtex-fs fonts-cwtex-docs fonts-wqy-microhei fonts-wqy-zenhei xfonts-wqy fonts-hanazono && \
    apt-get install -yq --no-install-recommends language-pack-zh* && \
    apt-get install -yq --no-install-recommends chinese* && \
    apt-get install -yq --no-install-recommends fonts-arphic-ukai fonts-arphic-uming fonts-ipafont-mincho fonts-ipafont-gothic fonts-unfonts-core \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

ADD fix-permissions /usr/local/bin/fix-permissions
# Create jovyan user with UID=1000 and in the 'users' group
# and make sure these dirs are writable by the `users` group.
RUN useradd -m -s /bin/bash -N -u $NB_UID $NB_USER && \
    mkdir -p $CONDA_DIR && \
    chown $NB_USER:$NB_GID $CONDA_DIR && \
    chmod g+w /etc/passwd /etc/group && \
    fix-permissions $HOME && \
    fix-permissions $CONDA_DIR

# Setup work directory for backward-compatibility
RUN mkdir /home/$NB_USER/work && \
    fix-permissions /home/$NB_USER

USER $NB_USER
# Install conda as jovyan and check the md5 sum provided on the download site
RUN cd /tmp && \
    wget --quiet https://repo.continuum.io/miniconda/Miniconda3-${MINICONDA_VERSION}-Linux-x86_64.sh && \
    #echo "${MINICONDA_CHECKSUM} *Miniconda3-${MINICONDA_VERSION}-Linux-x86_64.sh" | md5sum -c - && \
    /bin/bash Miniconda3-${MINICONDA_VERSION}-Linux-x86_64.sh -f -b -p $CONDA_DIR && \
    rm Miniconda3-${MINICONDA_VERSION}-Linux-x86_64.sh && \
    $CONDA_DIR/bin/conda config --system --prepend channels conda-forge && \
    $CONDA_DIR/bin/conda config --system --set auto_update_conda false && \
    $CONDA_DIR/bin/conda config --system --set show_channel_urls true && \
    $CONDA_DIR/bin/conda update --all --quiet --yes

# Conda Install ###########################################################################################
# Conda相關安裝套件 按照不同通道安裝(通道按照重要性分排序)
# 'conda clean --source-cache' is deprecated -> Use 'conda build purge-all' to remove source cache files.
###########################################################################################################
 
# 安裝 Jupyter Notebook 、 Hub 以及其他相關必要套件 
RUN conda install --quiet --yes \
    # 通道順序設定(按照重要性排序)
    -c anaconda -c conda-forge -c r -c pytorch -c menpo \
    # 套件清單(按照字母排序)
    beautifulsoup4 \
    conda-build cython cloudpickle contextlib2 \
    h5py hdf5 \
    ipywidgets \
    gsl \
    jupyterhub jupyterlab \
    keras-gpu \
    libgcc libstdcxx-ng lxml \
    mesa-libegl-cos6-x86_64 matplotlib matplotlib-base \
    notebook nomkl numexpr numpy numba \
    pytorch-nightly pandas patsy protobuf pyspark pillow \
    r-essentials \
    scikit-learn scikit-image sympy seaborn scipy statsmodels sqlalchemy \
    torchvision tini \
    vincent \
    xlrd xeus-cling

# 清除快取套件
RUN conda clean -tipsy && \
    npm cache clean --force && \
    rm -rf $CONDA_DIR/share/jupyter/lab/staging && \
    rm -rf /home/$NB_USER/.cache/yarn && \
    fix-permissions $CONDA_DIR && \
    fix-permissions /home/$NB_USER

# 清除conda快取
RUN conda build purge-all

# Install conda bioconda通道套件
RUN conda install --quiet --yes -c bioconda \ 
    cnv_facets

# Install conda creditx通道套件
#RUN conda install -c creditx nbresuse

RUN conda update --all

# Install Jupyer Hub 相關支援插件 Dependencies
    ## JupyterLab Status Bar
RUN pip install nbresuse && \
    jupyter serverextension enable --py nbresuse

# jupyter labextension (jupyterlab_iframe) ######################
# Open a site in a widget, or add a set of "quicklinks".
# https://github.com/timkpaine/jupyterlab_iframe/
#################################################################
RUN pip install jupyterlab_iframe && \
    jupyter labextension install jupyterlab_iframe && \
    jupyter serverextension enable --py jupyterlab_iframe

# jupyter labextension (JupyterLab Top Bar) ####################################################################
# Similar to the status bar, the top bar can be used to place a few indicators and optimize the overall space.
# https://github.com/jtpio/jupyterlab-topbar
################################################################################################################
RUN jupyter labextension install jupyterlab-topbar-extension \
    jupyterlab-system-monitor \
    jupyterlab-topbar-text \
    jupyterlab-logout \
    jupyterlab-theme-toggle

# jupyter labextension (jupyterlab-git) ####################
# A JupyterLab extension for version control using git
# https://github.com/jupyterlab/jupyterlab-git
############################################################
RUN pip install --upgrade jupyterlab-git && \
    jupyter lab build

# jupyter labextension (Jupyterlab Code Formatter) #######################################
# This is a small Jupyterlab plugin to support using 
# various code formatter on the server side and format code cells/files in Jupyterlab.
# 
##########################################################################################
RUN conda install -c conda-forge black && \
    jupyter labextension install @ryantam626/jupyterlab_code_formatter && \
    conda install -c conda-forge jupyterlab_code_formatter && \
    jupyter serverextension enable --py jupyterlab_code_formatter

# jupyter labextension (Jupyterlab-Tensorboard) ########
# https://github.com/chaoleili/jupyterlab_tensorboard 
# A JupyterLab extension for tensorboard.
# 1.Prerequisites(前置安裝) Jupyter_tensorboard
#
########################################################
RUN pip install tensorflow-gpu jupyter-tensorboard && \
    jupyter labextension install jupyterlab_tensorboard

# jupyter labextension (JupyterLab Spreadsheet) ###############
# https://github.com/quigleyj97/jupyterlab-spreadsheet
# This plugin adds a simple spreadsheet viewer to JupyterLab.
# 
###############################################################
RUN jupyter labextension install jupyterlab-spreadsheet

# jupyter labextension (jupyterlab-drawio) ################################################
# https://github.com/QuantStack/jupyterlab-drawio
# A JupyterLab extension for standalone integration of drawio / mxgraph into jupyterlab.
#
###########################################################################################
RUN jupyter labextension install jupyterlab-drawio

# jupyter labextension (jupyterlab-chart-editor) ###########################
# https://github.com/plotly/jupyterlab-chart-editor
# A JupyterLab extension for creating and editing Plotly charts
# 1.Prerequisites(前置安裝) plotly.py >= 3.3.0
#
############################################################################
RUN conda install -c plotly plotly=4.4.1 && \
    jupyter labextension install jupyterlab-chart-editor

# jupyter labextension (jupyterlab-toc) ######################
# https://github.com/jupyterlab/jupyterlab-toc
# A Table of Contents extension for JupyterLab
# This auto-generates a table of contents in the left area
# 
##############################################################
RUN jupyter labextension install @jupyterlab/toc

# jupyter labextension (JupyterLab GPU Dashboards) ###################################
# https://github.com/jacobtomlinson/jupyterlab-nvdashboard#jupyterlab-gpu-dashboards
# A JupyterLab extension for displaying dashboards of GPU usage.
# 1.Prerequisites(前置安裝) bokeh pynvml
# 伺服器與客戶端互相安裝對應系統(client端)
# 
######################################################################################
RUN pip install pynvml && \
    conda install bokeh && \
    jupyter labextension install jupyterlab-nvdashboard

# jupyter labextension (jupyter-matplotlib) ############################################
# https://github.com/matplotlib/jupyter-matplotlib
# jupyter-matplotlib enables the interactive features of matplotlib in the Jupyterlab
#
########################################################################################
RUN conda install -c conda-forge ipympl && \
    conda install nodejs && \
    jupyter labextension install @jupyter-widgets/jupyterlab-manager && \
    jupyter labextension install jupyter-matplotlib

# Install Jupyer Hub 相關支援插件-重要核心
#RUN jupyter labextension install \
    ## jupyterlab_sandbox 參考來源:https://github.com/canavandl/jupyterlab_sandbox (暫時不支援)
    #jupyterlab_sandbox

# Install Jupyer Hub 相關支援插件-@jupyterlab
RUN jupyter labextension install \
    @jupyterlab/github \
    #@jupyterlab/google-drive \ #因為學校網域因此必須放棄
    @jupyterlab/celltags

# Install Jupyer Hub 相關支援插件-Theme
RUN jupyter labextension install \
    #@kenshohara/theme-nord-extension
    #@rahlir/theme-gruvbox \
    @oriolmirosa/jupyterlab_materialdarker \
    # jupyterlab_html 參考來源:https://github.com/mflevine/jupyterlab_html
    @mflevine/jupyterlab_html

# Install Jupyer Hub 相關支援插件-其他    
RUN jupyter labextension install \
    @krassowski/jupyterlab_go_to_definition
    #@lckr/jupyterlab_variableinspector

RUN jupyter labextension install @jupyter-widgets/jupyterlab-manager

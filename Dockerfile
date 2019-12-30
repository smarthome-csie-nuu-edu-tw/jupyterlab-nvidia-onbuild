# Copyright (c) Jupyter Development Team.
# Distributed under the terms of the Modified BSD License.

FROM nvidia/cuda:10.0-cudnn7-devel
LABEL maintainer="ZiYi <osirisgekkou@gmail.com>"
USER root

# Install all OS dependencies for notebook server that starts but lacks all
# features (e.g., download as all possible file formats)
ENV DEBIAN_FRONTEND noninteractive
# Tensorflow Allowing GPU memory growth
ENV TF_FORCE_GPU_ALLOW_GROWTH true

# darknetpy環境設定
ENV GPU 1
ENV CUDNN 1
ENV OPENCV 1
ENV OPENMP 1

#fix problems
#RUN apt-get update && apt-get install -y --no-install-recommends apt-utils

RUN apt-get update && apt-get -yq dist-upgrade \
    && apt-get install -yq --no-install-recommends \
    apt-utils autoconf automake \
    bzip2 build-essential \
    ca-certificates cmake clang \
    default-jre \
    emacs \
    fonts-liberation ffmpeg \
    git graphviz \
    php7.2 php7.2-dev php-zmq \
    inkscape \
    jed \
    libsm6 libxext-dev libxrender1 lmodern locales \
    libreadline-dev libopencv-dev libzmq3-dev libtool \
    libssl-dev libglu1-mesa-dev \
    make mesa-common-dev \
    nano \
    openssh-client \
    pandoc python-dev python-pydot python-pydot-ng pkg-config pv protobuf-compiler python-pil python-lxml python-tk \
    rename \
    sudo \
    texlive-fonts-extra texlive-fonts-recommended texlive-generic-recommended texlive-latex-base texlive-latex-extra texlive-xetex \
    unrar unzip \
    vim \
    wget \
    zip \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

RUN apt-get update && \
    apt-get install -yq --no-install-recommends fonts-moe-standard-song fonts-moe-standard-kai fonts-cns11643-sung fonts-cns11643-kai fonts-arphic-ukai \
    fonts-arphic-uming fonts-arphic-bkai00mp fonts-arphic-bsmi00lp fonts-arphic-gbsn00lp fonts-arphic-gkai00mp fonts-cwtex-ming fonts-cwtex-kai fonts-cwtex-heib \
    fonts-cwtex-yen fonts-cwtex-fs fonts-cwtex-docs fonts-wqy-microhei fonts-wqy-zenhei xfonts-wqy fonts-hanazono && \
    apt-get install -yq --no-install-recommends language-pack-zh* && \
    apt-get install -yq --no-install-recommends chinese* && \
    apt-get install -yq --no-install-recommends fonts-arphic-ukai fonts-arphic-uming fonts-ipafont-mincho fonts-ipafont-gothic fonts-unfonts-core \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

RUN echo "en_US.UTF-8 UTF-8" > /etc/locale.gen && \
    locale-gen

# Configure environment
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

ADD fix-permissions /usr/local/bin/fix-permissions
# Create jovyan user with UID=1000 and in the 'users' group
# and make sure these dirs are writable by the `users` group.
RUN useradd -m -s /bin/bash -N -u $NB_UID $NB_USER && \
    mkdir -p $CONDA_DIR && \
    chown $NB_USER:$NB_GID $CONDA_DIR && \
    chmod g+w /etc/passwd /etc/group && \
    fix-permissions $HOME && \
    fix-permissions $CONDA_DIR

# Install Matlab
COPY R2018b_glnxa64 /R2018b_glnxa64
RUN cd /R2018b_glnxa64 && \
    ./install -inputFile /R2018b_glnxa64/installer_input.txt \
    -mode silent -agreeToLicense yes \ 
    -fileInstallationKey 54381-06086-22271-07865-07973-57612-08699-41920-10046-48326-20655-22750-19468-45951-61382-62144-21813-58580-33466-41322-11897 \
    -licensePath /R2018b_glnxa64/network.lic

#USER $NB_UID

# Setup work directory for backward-compatibility
RUN mkdir /home/$NB_USER/work && \
    fix-permissions /home/$NB_USER

# Install conda as jovyan and check the md5 sum provided on the download site
# 限制:OSError: MATLAB Engine for Python supports Python version 2.7, 3.5 and 3.6
ENV MINICONDA_VERSION 4.3.31
ENV MINICONDA_CHECKSUM 7fe70b214bee1143e3e3f0467b71453c
#ENV MINICONDA_VERSION latest
#ENV MINICONDA_CHECKSUM 718259965f234088d785cad1fbd7de03
RUN cd /tmp && \
    wget --quiet https://repo.continuum.io/miniconda/Miniconda3-${MINICONDA_VERSION}-Linux-x86_64.sh && \
    echo "${MINICONDA_CHECKSUM} *Miniconda3-${MINICONDA_VERSION}-Linux-x86_64.sh" | md5sum -c - && \
    /bin/bash Miniconda3-${MINICONDA_VERSION}-Linux-x86_64.sh -f -b -p $CONDA_DIR && \
    rm Miniconda3-${MINICONDA_VERSION}-Linux-x86_64.sh && \
    $CONDA_DIR/bin/conda config --system --prepend channels conda-forge && \
    $CONDA_DIR/bin/conda config --system --set auto_update_conda false && \
    $CONDA_DIR/bin/conda config --system --set show_channel_urls true && \
    $CONDA_DIR/bin/conda update --all --quiet --yes && \
#WARNING: 'conda clean --source-cache' is deprecated.
# Use 'conda build purge-all' to remove source cache files.
    #conda build purge-all && \
    conda clean -tipsy && \
    rm -rf /home/$NB_USER/.cache/yarn && \
    fix-permissions $CONDA_DIR && \
    fix-permissions /home/$NB_USER 
 
# 安裝 Jupyter Notebook 、 Hub 以及其他相關必要套件 
RUN conda install --quiet --yes \
    # 通道順序設定(按照重要性排序)
    -c anaconda -c conda-forge -c pytorch \
    # 套件清單(按照字母排序)
    beautifulsoup4 bokeh black \
    conda-build cython cloudpickle contextlib2 \
    h5py hdf5 \
    ipywidgets \
    jupyterlab_code_formatter jupyternotify jupyter_contrib_nbextensions jupyter_nbextensions_configurator jupyterlab-git \
    gsl \
    jupyterhub \
    keras-gpu \
    libgcc libstdcxx-ng lxml \
    mesa-libegl-cos6-x86_64 matplotlib matplotlib-base \
    #'notebook=5.*' \
    notebook nomkl numexpr numpy numba \
    #'jupyterhub=0.8.*' \
    pytorch-nightly pandas patsy protobuf pyspark pillow \
    scikit-learn scikit-image sympy seaborn scipy statsmodels sqlalchemy \
    torchvision tini tensorflow-tensorboard tensorflow-gpu \
    vincent \
    xlrd xeus-cling \
    && \
    #'jupyterlab=0.*' \
    conda install --quiet --yes -c conda-forge jupyterlab \ 
    # 清除快取套件
    && conda clean -tipsy && \
    npm cache clean --force && \
    rm -rf $CONDA_DIR/share/jupyter/lab/staging && \
    rm -rf /home/$NB_USER/.cache/yarn && \
    fix-permissions $CONDA_DIR && \
    fix-permissions /home/$NB_USER

# Conda尚未安裝套件(可能衝突或是其他原因而拋棄套件)
# dlib

# 清除conda快取
RUN conda build purge-all
 
# 添加 Matlab python API (need Root權限和conda安裝)
RUN cd /usr/local/MATLAB/R2018b/extern/engines/python && \
    python setup.py install

# Install conda menpo通道套件
RUN conda install --quiet --yes -c menpo \
    opencv3 

# Install conda bioconda通道套件
RUN conda install --quiet --yes -c bioconda \ 
    cnv_facets

# Install conda r通道套件
RUN conda install -c r \
    r-essentials

# Install conda creditx通道套件
#RUN conda install -c creditx nbresuse

RUN conda update --all

# Install Jupyer Hub 相關支援插件 Dependencies
    ## JupyterLab Status Bar
RUN pip install nbresuse && \
    jupyter serverextension enable --py nbresuse

# Install jupyterlab_iframe 相關支援插件 參考來源:https://github.com/timkpaine/jupyterlab_iframe/
RUN pip install jupyterlab_iframe && \
    jupyter labextension install jupyterlab_iframe

# Install Jupyer Hub 相關支援插件-重要核心
RUN jupyter labextension install \
    ## jupyterlab_tensorboard 參考來源:https://github.com/chaoleili/jupyterlab_tensorboard 
    jupyterlab_tensorboard \
    ## JupyterLab Top Bar 參考來源:https://github.com/jtpio/jupyterlab-topbar
    jupyterlab-topbar-extension \
    jupyterlab-system-monitor \
    jupyterlab-topbar-text \
    jupyterlab-logout \
    #jupyterlab-theme-toggle \ 故障
    ## jupyterlab-drawio 參考來源:https://github.com/QuantStack/jupyterlab-drawio
    jupyterlab-drawio \
    ## jupyterlab-spreadsheet 參考來源:https://github.com/quigleyj97/jupyterlab-spreadsheet
    jupyterlab-spreadsheet \
    ## jupyterlab-chart-editor 參考來源:https://github.com/plotly/jupyterlab-chart-editor
    jupyterlab-chart-editor
    ## jupyterlab_sandbox 參考來源:https://github.com/canavandl/jupyterlab_sandbox (暫時不支援)
    #jupyterlab_sandbox

# Install Jupyer Hub 相關支援插件-@jupyterlab
RUN jupyter labextension install \
    @jupyterlab/toc \
    @jupyterlab/github \
    @jupyterlab/hub-extension \
    #@jupyterlab/google-drive \ #因為學校網域因此必須放棄
    @jupyterlab/git \
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
    @ryantam626/jupyterlab_code_formatter \
    @krassowski/jupyterlab_go_to_definition
    #@lckr/jupyterlab_variableinspector

# Jupyter Hub 啟動功能
RUN jupyter serverextension enable --py \
    jupyterlab_code_formatter \
    jupyterlab_git \
    jupyterlab_iframe

RUN jupyter labextension install @jupyter-widgets/jupyterlab-manager

# IJava
RUN cd /tmp && \
    git clone https://github.com/SpencerPark/IJava.git && \
    cd IJava && \
    chmod u+x gradlew && ./gradlew installKernel

# Jupyter-PHP kernel
RUN cd /tmp && \
    ## Download Composer
    php -r "copy('https://getcomposer.org/installer', 'composer-setup.php');" && \
    # 下載檔案驗證機制
    #php -r "if (hash_file('sha384', 'composer-setup.php') === 'a5c698ffe4b8e849a443b120cd5ba38043260d5c4023dbf93e1558871f1f07f58274fc6f4c93bcfd858c6bd0775cd8d1') { echo 'Installer verified'; } else { echo 'Installer corrupt'; unlink('composer-setup.php'); } echo PHP_EOL;" && \
    php composer-setup.php && \
    php -r "unlink('composer-setup.php');" && \
    ## jupyter-php-installer
    wget https://litipk.github.io/Jupyter-PHP-Installer/dist/jupyter-php-installer.phar && \
    chmod +x ./jupyter-php-installer.phar && \
    ./jupyter-php-installer.phar install

# Build recommend 對話框修復
RUN jupyter lab build

# conda清理與準備
RUN conda clean -tipsy && \
    jupyter nbextension enable --py widgetsnbextension --sys-prefix && \
    npm cache clean --force && \
    rm -rf $CONDA_DIR/share/jupyter/lab/staging && \
    rm -rf /home/$NB_USER/.cache/yarn && \
    rm -rf /home/$NB_USER/.node-gyp && \
    fix-permissions $CONDA_DIR && \
    fix-permissions /home/$NB_USER

# pip install list
RUN pip install --upgrade pip && \
    pip install \
    cupy chainer \
    face_recognition \
    matlab_kernel

# 原生 Install dlib GPU 
RUN cd /tmp && \
    git clone https://github.com/davisking/dlib.git && \
    cd dlib && \
    python setup.py install && \
    rm -rf dlib && \
    fix-permissions $CONDA_DIR && \
    fix-permissions /home/$NB_USER

# Import matplotlib the first time to build the font cache.
ENV XDG_CACHE_HOME /home/$NB_USER/.cache/
RUN MPLBACKEND=Agg python -c "import matplotlib.pyplot" && \
    fix-permissions /home/$NB_USER

# Fix CMAKE問題 放棄
#RUN rm /usr/lib/x86_64-linux-gnu/libEGL.so && \
#    ln /usr/lib/x86_64-linux-gnu/libEGL.so.1 /opt/conda/bin/../x86_64-conda_cos6-linux-gnu/sysroot/usr/lib64/libEGL.so

# QT5安裝 放棄
#RUN cd /tmp && \
#    wget http://download.qt.io/official_releases/qt/5.13/5.13.1/qt-opensource-linux-x64-5.13.1.run && \
#    chmod +x qt-opensource-linux-x64-5.13.1.run && \
#    ./qt-opensource-linux-x64-5.13.1.run -y 

# CUDA CMAKE (因QT問題無法安裝 須修正)
#RUN cd /tmp && \
#    git clone https://github.com/Kitware/CMake.git && \
#    cd CMake && \
#    ./bootstrap && make -j8 && make install

#參考來源:https://github.com/nagadomi/distro https://github.com/nagadomi/waifu2x/issues/253
ENV TORCH_NVCC_FLAGS -D__CUDA_NO_HALF_OPERATORS__
RUN git clone https://github.com/nagadomi/distro.git ~/torch --recursive && \
    cd ~/torch && \
    ./install-deps && \
    ./clean.sh && \
    ./install.sh && \
    ./clean.sh && \
    ./update.sh

RUN cd ~//torch/extra/cutorch && \
    ~/torch/install/bin/luarocks make rocks/cutorch-scm-1.rockspec

RUN cd ~/torch/install/bin/ && \
    for NAME in dpnn nn optim optnet csvigo cunn fblualib torchx tds; \
    do ./luarocks install $NAME; \
    done

## Rust Programming Language
COPY rustup-init.sh /tmp
RUN cd /tmp && \
    sh rustup-init.sh -y -v
ENV PATH=$PATH:$HOME/.cargo/bin
RUN rustup default nightly
RUN rustc --version

RUN fix-permissions $CONDA_DIR && \
    fix-permissions /home/$NB_USER

####################
#使用者資料夾資料
####################

USER $NB_USER

# 收集常用或精華的GIT範例資料
RUN cd /home/$NB_USER && \
    git clone https://github.com/ageitgey/face_recognition.git && \
    git clone https://github.com/tensorflow/tensorflow.git && \
    # Microsoft Emotion API: Jupyter Notebook
    git clone https://github.com/microsoft/Cognitive-Emotion-Python.git && \
    # TensorFlow Documentation
    git clone https://github.com/tensorflow/docs.git 'tensorflow說明文件'
# OpenFace installation and models download
RUN cd  /home/$NB_USER && \
    git clone https://github.com/cmusatyalab/openface.git && \
    cd openface && \
    bash models/get-models.sh && \
    python setup.py install
RUN cd  /home/$NB_USER && \
    git clone https://github.com/tensorflow/models.git 'tensorflow/models' && \
    cd tensorflow/models/research && \
    protoc object_detection/protos/*.proto --python_out=. && \
    python setup.py build && \
    python setup.py install && \
    cd slim && \
    rm -R BUILD && \
    python setup.py build && \
    python setup.py install
## COCO API installation
RUN cd /home/$NB_USER && \
    git clone https://github.com/cocodataset/cocoapi.git && \
    cd cocoapi/PythonAPI && \
    make -j8 && \
    cp -r pycocotools ../../tensorflow/models/research/ && \
    python setup.py build && \
    python setup.py install
# DarkNet 安裝
RUN cd /home/$NB_USER && \
    #cd darknet && \
    git clone https://github.com/AlexeyAB/darknet.git && \
    cd darknet && \
    # 修改Makefile內參數設定 XXs代表行數
    sed -i "1s/.*/GPU=1/" Makefile && \
    sed -i "2s/.*/CUDNN=1/" Makefile && \
    sed -i "3s/.*/CUDNN_HALF=1/" Makefile && \
    sed -i "4s/.*/OPENCV=1/" Makefile && \
    sed -i "29s/.*/ARCH= -gencode arch=compute_75,code=[sm_75,compute_75]/" Makefile && \
    # 下載yolov3檔案
    wget https://pjreddie.com/media/files/yolov3.weights && \
    mkdir build-release && \
    cd build-release && \
    cmake .. && \
    make && \
    make install
## Protobuf Compilation
#RUN cd /home/$NB_USER && \
#    cd tensorflow/models/research/ && \
#    protoc object_detection/protos/*.proto --python_out=. && \
#    export PYTHONPATH=$PYTHONPATH:pwd:pwd/slim
## 資料集下載 Quick Start: Distributed Training on the Oxford-IIIT Pets Dataset on Google Cloud
RUN cd /home/$NB_USER && \
    cd tensorflow/models/research/ && \
    wget http://www.robots.ox.ac.uk/~vgg/data/pets/data/images.tar.gz && \
    wget http://www.robots.ox.ac.uk/~vgg/data/pets/data/annotations.tar.gz && \
    tar -xvf images.tar.gz && \
    tar -xvf annotations.tar.gz
# 系統服務簡易說明書
COPY 使用注意事項 /home/$NB_USER/
     
# nodejs kernel
RUN npm install -g ijavascript && \
    ijsinstall

### Matlab Configure
# add Matlab Command
ENV PATH="/usr/local/MATLAB/R2018b/bin/:$PATH"

RUN ["/bin/bash", "-c", "cd ~/torch && source ~/.bashrc"]

USER root

# DarkNet 修正
# 修正部分錯誤 error while loading shared libraries: libopencv_highgui.so.3.1: cannot open shared object file: No such file or directory
RUN echo "/opt/conda/pkgs/opencv3-3.1.0-py36_0/lib" > /etc/ld.so.conf.d/opencv.conf && \
    ldconfig

#################### Beta測試專區 ##################
#RUN apt-get update && apt-get install -yq --no-install-recommends \

# Install conda conda-forge通道套件

# 暫時放棄有BUG
#RUN pip install -U darknetpy

#################### Beta測試專區 ################## END

EXPOSE 8888
WORKDIR $HOME

# Configure container startup
ENTRYPOINT ["tini", "--"]
CMD ["start-notebook.sh"]

# Add local files as late as possible to avoid cache busting
COPY start.sh /usr/local/bin/
COPY start-notebook.sh /usr/local/bin/
COPY start-singleuser.sh /usr/local/bin/
COPY jupyter_notebook_config.py /etc/jupyter/
RUN fix-permissions /etc/jupyter/

## Startup Scripts
COPY user-settings /home/jovyan/.jupyter/lab/user-settings
COPY custom_ml_data_set /home/jovyan/資工系深度學習樣本
COPY smart_home_source_code  /home/jovyan/智慧宅原始碼
COPY fflang_disk /home/jovyan/黃老師客家語音合成服務
COPY smart_home_doc /home/jovyan/廠商開發官方說明文件
#COPY drive.jupyterlab-settings /home/jovyan/.jupyter/lab/user-settings/@jupyterlab/google-drive/drive.jupyterlab-settings
COPY startup.py /home/$NB_USER/.ipython/profile_default/startup/
RUN fix-permissions /home/$NB_USER/.ipython/
# 修正那些資工系的資料或廠商資料
RUN fix-permissions /home/$NB_USER/

#################### gamma測試專區(汪子軼用) ################## (ROOT)

RUN apt-get install -y mercurial python-gi-cairo gir1.2-goocanvas-2.0 python-gi python-pygraphviz

#################### gamma測試專區(汪子軼用) ################## (ROOT)

# Switch back to jovyan to avoid accidental container runs as root
USER $NB_UID

#################### gamma測試專區(汪子軼用) ##################

RUN npm install ws mqtt

RUN pip install flask flask-mqtt flask-socketio

#################### gamma測試專區(汪子軼用) ##################

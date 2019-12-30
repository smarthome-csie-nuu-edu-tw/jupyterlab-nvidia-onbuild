# Copyright (c) Jupyter Development Team.
# Distributed under the terms of the Modified BSD License.

FROM ziyibear/jupyterlab-nvidia-onbuild:2080ti
LABEL maintainer="ZiYi <osirisgekkou@gmail.com>"
USER root

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

# 清除conda快取
RUN conda build purge-all
 
# 添加 Matlab python API (need Root權限和conda安裝)
RUN cd /usr/local/MATLAB/R2018b/extern/engines/python && \
    python setup.py install

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

### Matlab Configure
# add Matlab Command
ENV PATH="/usr/local/MATLAB/R2018b/bin/:$PATH"

RUN ["/bin/bash", "-c", "cd ~/torch && source ~/.bashrc"]

USER root

# DarkNet 修正
# 修正部分錯誤 error while loading shared libraries: libopencv_highgui.so.3.1: cannot open shared object file: No such file or directory
RUN echo "/opt/conda/pkgs/opencv3-3.1.0-py36_0/lib" > /etc/ld.so.conf.d/opencv.conf && \
    ldconfig

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

#################### gamma測試專區(汪子軼用) ################## (ROOT)

# Switch back to jovyan to avoid accidental container runs as root
USER $NB_UID

#################### gamma測試專區(汪子軼用) ##################

RUN npm install ws mqtt

RUN pip install flask flask-mqtt flask-socketio

#################### gamma測試專區(汪子軼用) ##################

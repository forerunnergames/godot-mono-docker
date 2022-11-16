FROM alpine as files

WORKDIR /files

RUN apk add -U unzip && rm -rf /var/cache/apk/*

ENV GODOT_VERSION "3.5.1"
ENV RELEASE_NAME "stable"

# This is only needed for non-stable builds (alpha, beta, RC)
# e.g. SUBDIR "/beta3"
# Use an empty string "" when the RELEASE_NAME is "stable"
ENV SUBDIR ""

RUN wget -O /tmp/godot.zip https://downloads.tuxfamily.org/godotengine/${GODOT_VERSION}${SUBDIR}/mono/Godot_v${GODOT_VERSION}-${RELEASE_NAME}_mono_linux_headless_64.zip
RUN unzip /tmp/godot.zip -d /tmp/godot
RUN mv /tmp/godot/* /files

RUN wget -O /tmp/godot_templates.tpz https://downloads.tuxfamily.org/godotengine/${GODOT_VERSION}${SUBDIR}/mono/Godot_v${GODOT_VERSION}-${RELEASE_NAME}_mono_export_templates.tpz
RUN unzip /tmp/godot_templates.tpz -d /tmp/godot_templates
RUN mv /tmp/godot_templates/* /files

RUN wget -O /tmp/android_sdk.zip https://dl.google.com/android/repository/commandlinetools-linux-8512546_latest.zip
RUN unzip /tmp/android_sdk.zip -d /tmp/android_sdk
RUN mv /tmp/android_sdk/* /files

FROM mono:latest

USER root

ENV DEBIAN_FRONTEND=noninteractive
ENV GODOT_VERSION "3.5.1"
ENV RELEASE_NAME "stable"
ENV ANDROID_SDK_PLATFORM 31
ENV ANDROID_BUILD_TOOLS 30.0.3
ENV ANDROID_HOME="/usr/lib/android-sdk"

RUN apt-get update && apt-get install -y --no-install-recommends \
    unzip \
    wget \
    python \
    openjdk-11-jdk-headless \
    && rm -rf /var/lib/apt/lists/*

COPY --from=files /files/Godot_v${GODOT_VERSION}-${RELEASE_NAME}_mono_linux_headless_64/Godot_v${GODOT_VERSION}-${RELEASE_NAME}_mono_linux_headless.64 /usr/local/bin/godot
COPY --from=files /files/Godot_v${GODOT_VERSION}-${RELEASE_NAME}_mono_linux_headless_64/GodotSharp /usr/local/bin/GodotSharp
COPY --from=files /files/templates /root/.local/share/godot/templates/${GODOT_VERSION}.${RELEASE_NAME}.mono
COPY --from=files /files/cmdline-tools ${ANDROID_HOME}/cmdline-tools/latest

ENV PATH="${ANDROID_HOME}/cmdline-tools/cmdline-tools/latest/bin:${PATH}"

RUN  yes | ${ANDROID_HOME}/cmdline-tools/latest/bin/sdkmanager --licenses
RUN  ${ANDROID_HOME}/cmdline-tools/latest/bin/sdkmanager "platform-tools" "build-tools;${ANDROID_BUILD_TOOLS}" "platforms;android-${ANDROID_SDK_PLATFORM}" "cmdline-tools;latest" "cmake;3.10.2.4988404" "ndk;21.4.7075529"

RUN keytool -keyalg RSA -genkeypair -alias androiddebugkey -keypass android -keystore debug.keystore -storepass android -dname "CN=Android Debug,O=Android,C=US" -validity 9999 \
    && mv debug.keystore /root/debug.keystore

RUN godot -e -v -q

RUN echo 'export/android/android_sdk_path = "/usr/lib/android-sdk"' >> ~/.config/godot/editor_settings-3.tres
RUN echo 'export/android/debug_keystore = "/root/debug.keystore"' >> ~/.config/godot/editor_settings-3.tres
RUN echo 'export/android/debug_keystore_user = "androiddebugkey"' >> ~/.config/godot/editor_settings-3.tres
RUN echo 'export/android/debug_keystore_pass = "android"' >> ~/.config/godot/editor_settings-3.tres
RUN echo 'export/android/force_system_user = false' >> ~/.config/godot/editor_settings-3.tres
RUN echo 'export/android/timestamping_authority_url = ""' >> ~/.config/godot/editor_settings-3.tres
RUN echo 'export/android/shutdown_adb_on_exit = true' >> ~/.config/godot/editor_settings-3.tres
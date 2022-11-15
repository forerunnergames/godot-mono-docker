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
ENV ANDROID_SDK_PLATFORM 31
ENV ANDROID_BUILD_TOOLS 30.0.3
ENV RELEASE_NAME "stable"

RUN apt-get update && apt-get install -y --no-install-recommends sudo openjdk-11-jdk unzip

COPY --from=files /files/Godot_v${GODOT_VERSION}-${RELEASE_NAME}_mono_linux_headless_64/Godot_v${GODOT_VERSION}-${RELEASE_NAME}_mono_linux_headless.64 /usr/local/bin/godot
COPY --from=files /files/Godot_v${GODOT_VERSION}-${RELEASE_NAME}_mono_linux_headless_64/GodotSharp /usr/local/bin/GodotSharp
COPY --from=files /files/cmdline-tools /opt/android-sdk/cmdline-tools
COPY --from=files /files/templates /root/.local/share/godot/templates/${GODOT_VERSION}.${RELEASE_NAME}.mono

RUN  yes | /opt/android-sdk/cmdline-tools/bin/sdkmanager --sdk_root=/opt/android-sdk/cmdline-tools --licenses
RUN  /opt/android-sdk/cmdline-tools/bin/sdkmanager --sdk_root=/opt/android-sdk/cmdline-tools "platform-tools" "platforms;android-$ANDROID_SDK_PLATFORM" "build-tools;${ANDROID_BUILD_TOOLS}"

RUN godot -e -v -q \
        && echo 'export/android/android_sdk_path = "/opt/android-sdk/cmdline-tools"' >> ./root/.config/godot/editor_settings-3.tres

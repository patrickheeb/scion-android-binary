- install Vagrant and VirtualBox
- run "vagrant up"
- executables will be generated in the "bin" directory
- after building, run "vagrant halt" (and possibly, "vagrant destroy" because the VM is no more needed)

To try these executables on an Android smartphone, connect it via USB, enable USB debugging mode and run adb as follows (on my Windows system, adb is located at %HOME%\AppData\Local\Android\Sdk\platform-tools\adb.exe):

adb push disp.toml /data/local/tmp
adb push bin/scion-android-linux_arm_pure_stripped /data/local/tmp/scion-android

adb shell, then run:
  cd /data/local/tmp
  chmod +x scion-android
  ./scion-android godispatcher -lib_env_config disp.toml
  
This does not work on my device ("bind: permission denied") but it should (?) work inside an app with the right permissions.
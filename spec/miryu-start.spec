
%global plugin_name    org.miryugaming.start
%global plugin_dir     %{_datadir}/plasma/plasmoids/%{plugin_name}
%global gettext_domain plasma_applet_%{plugin_name}

Name:           miryu-start
Version:        45.0.0
Release:        9%{?dist}
Summary:        Windows 11 style start menu with KDE Connect mobile panel

License:        GPL-3.0-or-later
URL:            https://github.com/evernightvista/miryu-start
Source0:        https://github.com/evernightvista/miryu-start/archive/refs/heads/main.zip

BuildRequires:  gettext
BuildRequires:  unzip

Requires:       plasma-workspace
Requires:       miryu-icon-theme
Requires:       kde-connect
Requires:       python3
Requires:       qt6-qttools
Requires:       miryu-start >= 45.0.0-4

BuildArch:      noarch

%description
Miryu Start

%prep
%autosetup -n miryu-start-main

%build
cd translate
sh build.sh

%install
rm -rf %{buildroot}

install -d %{buildroot}%{plugin_dir}
cp -a metadata.json %{buildroot}%{plugin_dir}/
cp -a contents     %{buildroot}%{plugin_dir}/


install -d %{buildroot}%{_datadir}/locale
cp -a %{buildroot}%{plugin_dir}/contents/locale/* %{buildroot}%{_datadir}/locale/

find %{buildroot}%{plugin_dir}   -type d -exec chmod 0755 {} \;
find %{buildroot}%{plugin_dir}   -type f -exec chmod 0644 {} \;
find %{buildroot}%{_datadir}/locale -type d -exec chmod 0755 {} \;
find %{buildroot}%{_datadir}/locale -type f -exec chmod 0644 {} \;


install -d %{buildroot}%{_datadir}/licenses/%{name}
install -m 0644 LICENSE %{buildroot}%{_datadir}/licenses/%{name}/

install -d %{buildroot}%{_datadir}/doc/%{name}
install -m 0644 README.md %{buildroot}%{_datadir}/doc/%{name}/


%find_lang %{gettext_domain}

%files -f %{gettext_domain}.lang
%license %{_datadir}/licenses/%{name}/LICENSE
%doc     %{_datadir}/doc/%{name}/README.md

%dir     %{plugin_dir}
%{plugin_dir}/metadata.json
%{plugin_dir}/contents/config/
%{plugin_dir}/contents/icons/
%{plugin_dir}/contents/ui/
%dir     %{plugin_dir}/contents
%dir     %{plugin_dir}/contents/locale

%changelog

* Wed Oct 28 2026 KairikiFedora <13278297951@sina.cn> - 45.0.0-9
- Add unamed folder auto follow locale and add rpmspec

* Wed Oct 28 2026 KairikiFedora <13278297951@sina.cn> - 45.0.0-8
- Fix Context Menu

* Wed Oct 28 2026 KairikiFedora <13278297951@sina.cn> - 45.0.0-7
- Fix Folder Drag bug and app drag bug

* Tue Oct 27 2026 KairikiFedora <13278297951@sina.cn> - 45.0.0-6
- Add Organize Folder Support

* Sat Oct 24 2026 KairikiFedora <13278297951@sina.cn> - 45.0.0-5
- Add FallBack avatar if not avatar

* Wed Oct 21 2026 KairikiFedora <13278297951@sina.cn> - 45.0.0-3
- Fix Load Favorite apps

* Wed Oct 21 2026 KairikiFedora <13278297951@sina.cn> - 45.0.0-2
- Fix Bugs

* Tue Oct 20 2026 KairikiFedora <13278297951@sina.cn> - 45.0.0-1
- Initial RPM package for Miryu Start 45.0.0

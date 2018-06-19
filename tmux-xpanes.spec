
Name:       tmux-xpanes
Summary:    Ultimate terminal divider powered by tmux
Version:    3.0.0
Group:      Applications
License:    MIT
Release:    %(date '+%'s)
URL:        https://github.com/greymd/tmux-xpanes
Source:     https://github.com/greymd/tmux-xpanes/archive/v%{version}.tar.gz
BuildArch:  noarch
Vendor:     Yamada, Yasuhiro <greengregson at gmail dot com>
Requires:   tmux
Provides:   tmux-xpanes, xpanes

BuildRoot: %(mktemp -ud %{_tmppath}/%{name}-%{version}-%{release}-XXXXXX)

%description
xpanes or tmux-xpanes (alias of xpanes) commands have following features:

  - Split tmux window into multiple panes.
  - Build command lines from given arguments & execute them on the panes.
  - Runnable from outside of tmux session.
  - Runnable from inside of tmux session.
  - Record operation log.
  - Layout arrangement for panes.
  - Display pane title on each pane
  - Generate command lines from standard input (Pipe mode).


%prep
%setup

%install
install -d -m 0755 %{buildroot}%{_mandir}/man1 %{buildroot}%{_bindir}
%{__cp} -a man/*.1 %{buildroot}%{_mandir}/man1/
%{__cp} -a bin/* %{buildroot}%{_bindir}/

%files
%defattr(0644, root, root, 0755)
%doc README.md CONTRIBUTING.md
%license LICENSE
%{_mandir}/man1/*
%attr(0755, root, root) %{_bindir}/*

%clean
%{__rm} -rf %{buildroot}


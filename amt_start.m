function amt_start(varargin)
%amt_start   Start the Auditory Modeling Toolbox (AMT)
%   Usage:  amt_start;
%           amt_start(flags);
%
%   AMT_START starts the AMT. This command must be
%   run before using any of the function in the AMT.
%
%   AMT_START('install') queries the user for yes/no to download and install
%   all available third-party toolboxes. Then, it executes amt_mex to compile
%   the binaries on the system.
%
%
%   Cache:
%   ------
%
%   AMT uses cache to store precalculated results because some of the AMT functions
%   require a large processing time. Depending on the machine and the model, it might take
%   even days. The global cache mode is controlled on start-up of the AMT. To change the
%   global cache mode choose a flags:
%
%     'normal'      Use cached package as far as possible. This is default.
%                   This is kind of demonstration mode and very convenient
%                   for fast access of results like plotting figures.
%                   This option, however, may by-pass the actual processing and thus
%                   does not always test the actual functionality of a model.
%                   If the cached package locally not available, downloaded from the internet.
%                   If remotely not available, enforce recalculation.
%
%     'cached'      Enforce to use cached package. If the cached package is
%                   locally not available, it will be downloaded from the internet.
%                   If it is remotely not available, an error will be thrown.
%
%     'redo'        Enforce the recalculation of the package. This option
%                   actually tests the calculations.
%
%     'localonly'   Package will be recalculated when locally
%                   not available. Do not connect to the internet.
%
%   Many AMT functions support the cache mode as input flag in order to
%   overwrite the global cache mode. See AMT_CACHE for more details.
%
%
%   Auxiliary data:
%   ---------------
%
%   Most of the models require auxiliary data, i.e., auxdata.
%   The download URL for the auxiliary data is given by amt_auxdataurl and
%   corresponding previous versions of the AMT (auxdata is versioned).
%   The AMT will download auxdata on-demand and cache in the auxdata directory.
%   If you want to run the AMT offline, download the auxiliary data first.
%   See AMT_LOAD for more details.
%
%
%   Display:
%   --------
%
%   The display of the messages to the command line can be controlled by one
%   of the following flags:
%
%     'verbose'        All output will be displayed. This is default.
%
%     'documentation'  starts the AMT in the documentation compiling
%                      mode. The output of calculation progress will be suppressed.
%
%     'silent'         All output will be suppressed.
%
%   Display of text in the AMT is handled by AMT_DISP.
%   See AMT_DISP for more details.
%
%
%   License:
%   --------
%
%   The AMT is a MULTIPLE-licenses software: Most of the files are
%   licensed under the GPL version 3.0, but some files are licensed differently.
%   Each file contains a separate license boilerplate showing the actual license.
%   For models being NOT under GPL3, the boilerplate is displayed on their first run.
%   If no license message is displayed, the model is licensed under the GPL3.
%   The information about the license of a model can be shown by AMT_INFO.
%
%   See also:  amt_mex amt_load amt_cache amt_disp amt_info
%
%   Url: http://amtoolbox.org/amt-1.6.0/doc/amt_start.php


%   #Author: Peter L. Soendergaard (2013)
%   #Author: Piotr Majdak (2013-)
%   #Author: Clara Hollomey(2020-2023)
%   #Author: Piotr Majdak (2023): fix for using cache flags in documentation mode
%   #Author: Piotr Majdak (2023): significantly refactored, with essential speed up, especially for the LTFAT start
%   #Author: Piotr Majdak (2024): BADS as third-party toolbox added
%   #Author: Michael Mihocic (2024): Bug fixed when checking for installed packages

% This file is licensed unter the GNU General Public License (GPL) either
% version 3 of the license, or any later version as published by the Free Software
% Foundation. Details of the GPLv3 can be found in the AMT directory "licences" and
% at <https://www.gnu.org/licenses/gpl-3.0.html>.
% You can redistribute this file and/or modify it under the terms of the GPLv3.
% This file is distributed without any warranty; without even the implied warranty
% of merchantability or fitness for a particular purpose.

%where are we?
global AMTuserpaths % here we store the user's search paths
resetpath = pwd;
basepath = which('amt_start.m');
basepath = basepath(1:end-numel('amt_start.m'));

%how should I display?
if any(strcmp(varargin, 'silent'))
    dispFlag = 'silent';
    silent = 1;
    documentation = 0;
elseif any(strcmp(varargin, 'documentation'))
    dispFlag = 'documentation';
    silent = 0;
    documentation = 1;
else
    dispFlag = 'verbose';
    silent = 0;
    documentation = 0;
end

if any(strcmp(varargin, 'install'))
    install = 1;
    debug = 1;
    dispFlag = 'verbose';
else
    install = 0;
    debug = 0;
end

%% In Octave, disable annoying warnings
if exist('OCTAVE_VERSION','builtin')
  warning('off','Octave:shadowed-function'); % Functions shadowing other functions
  warning('off','Octave:savepath-local'); % Saving the search paths locally
end

% get the default configuration without having the paths added yet
definput.keyvals.path=basepath;
cd(fullfile(basepath,'defaults'));
  definput = arg_amt_configuration(definput);
cd(resetpath);
definput.keyvals.amtrunning = 1;

% display splash screen
if ~silent
  disp(' ');
  disp('****************************************************************************');
  disp(' ');
  disp(['The Auditory Modeling Toolbox (AMT) version ', definput.keyvals.version{1}(5:end),'.']);
  disp('Brought to you by the AMT Team. See http://amtoolbox.org for more information.');
  disp(' ');
end
% if we install and AMT started before, restore the paths before installing
if install && ~isempty(AMTuserpaths)
  path(AMTuserpaths);
  AMTuserpaths=[];
end

thirdpartypath=fullfile(basepath,'thirdparty');
%% Checking and installing the obligatory io package if in Octave
if exist('OCTAVE_VERSION','builtin')
  if ~local_loadoctpkg('io')
    error(['Cannot load the package "io".'  ...
           'Check the package list with "pkg list" and/or install the package with "pkg install io" and/or try "sudo apt install octave-io"']);
  end
end

%% Checking and installing the obligatory LTFAT
toolboxname='ltfat'; targetfile='ltfatstart.m';
ltfatpath = local_loadtoolbox(toolboxname, targetfile, thirdpartypath);
if isempty(ltfatpath) % if locally not found, install
  ltfatpath = local_installtoolbox(toolboxname, targetfile, definput.keyvals.ltfat, thirdpartypath);
end
fid=fopen(fullfile(ltfatpath,'ltfat_version')); s=char(fread(fid)'); fclose(fid);
v=sscanf(s,'%d.%d.%d'); % the actual LTFAT version
s_r='2.4.0'; v_r=sscanf(s_r,'%d.%d.%d'); % the required version
if v(1)<v_r(1) || (v(1)>=v_r(1) && v(2)<v_r(2))
   error(['Your LTFAT has version ' s ' but you need LTFAT >= ' s_r '. ' 10 ...
          ' Update your LTFAT or remove the search path to your LTFAT to let the AMT install the correct LTFAT for you.']);
end
ltfattarget=['ltfatstart_' strrep(strtrim(s),'.','_')]; % check if a sped-up start of the LTFAT available
if ~exist(fullfile(thirdpartypath,[ltfattarget '.m']),'file')
  ltfattarget='ltfatstart'; % if not, use the default start
end

%% Checking/Installing the SOFA Toolbox
toolboxname='sofa'; targetfile = 'SOFAstart.m';
sofapath = local_loadtoolbox(toolboxname, targetfile, thirdpartypath);
if isempty(sofapath) && install % if locally not found, and install mode: install
    sofapath = local_installtoolbox(toolboxname, targetfile, definput.keyvals.sofa, thirdpartypath);
end

%% Checking/Installing the SFS Toolbox
toolboxname='sfs'; targetfile = 'SFS_start.m';
sfspath = local_loadtoolbox(toolboxname, targetfile, thirdpartypath);
if isempty(sfspath) && install
  sfspath = local_installtoolbox(toolboxname, targetfile, definput.keyvals.sfs, thirdpartypath);
end
  %if we have sfs installed, we should delete rms.m because of syntax conflicts
if ~isempty(sfspath)
  sfsdeletepath=fileparts(which('SFS_start.m'));
  if isoctave
    if exist(fullfile(sfsdeletepath,'SFS_octave','rms.m'),'file')
      delete(fullfile(sfsdeletepath,'SFS_octave','rms.m'));
    end
  else
    if exist(fullfile(sfsdeletepath,'SFS_general','rms.m'),'file')
      delete(fullfile(sfsdeletepath,'SFS_general','rms.m'));
    end
  end
end

%% Checking/Installing the Circular Statistics Toolbox
toolboxname='circstat'; targetfile = 'kuipertable.mat';
circstatpath = local_loadtoolbox(toolboxname, targetfile, thirdpartypath);
if isempty(circstatpath) && install
  circstatpath = local_installtoolbox(toolboxname, targetfile, definput.keyvals.circstat, thirdpartypath);
end

%% Checking/Installing the BinauralSH Toolbox
toolboxname='binauralSH'; targetfile = 'binauralSH_start.m';
binauralshpath = local_loadtoolbox(toolboxname, targetfile, thirdpartypath);
if isempty(binauralshpath) && install
  binauralshpath = local_installtoolbox(toolboxname, targetfile, definput.keyvals.binauralSH, thirdpartypath);
end

%% Checking/Installing the BADS Toolbox
toolboxname='bads'; targetfile = 'bads.m';
badspath = local_loadtoolbox(toolboxname, targetfile, thirdpartypath);
if isempty(badspath) && install % if locally not found, and install mode: install
    badspath = local_installtoolbox(toolboxname, targetfile, definput.keyvals.bads, thirdpartypath);
end

%% Store the user's path (updated by the installations, if required) for amt_stop
if isempty(AMTuserpaths)
  AMTuserpaths=path;
end

%% Setup the general AMT configuration
if exist('OCTAVE_VERSION','builtin')
  definput.keyvals.interpreter = 'Octave';
  definput.keyvals.interpreterversion = version;
else
  definput.keyvals.interpreter = 'Matlab';
  definput.keyvals.interpreterversion = version;
end

if isunix
  definput.keyvals.system = 'Linux';
elseif ismac
  definput.keyvals.system = 'Mac';
elseif ispc
  definput.keyvals.system = 'Windows';
else
  definput.keyvals.system = 'other';
end

%% Add AMT specfic search paths
adp=['''' basepath ''','];
if strcmp(definput.keyvals.interpreter, 'Octave')
  expectedFolders = numel(definput.keyvals.amt_folders);
else
  expectedFolders = numel(definput.keyvals.amt_folders) - 1;
end
for ii = 1:expectedFolders
    definput.keyvals.amt_folders(ii).name = [basepath, definput.keyvals.amt_folders(ii).name];
    adp=[adp '''' definput.keyvals.amt_folders(ii).name ''',' ];
end
eval(['addpath(' adp(1:end-1) ');']); % this is faster than addpath in a loop

%% check and start toolboxes (MATLAB) and packages (Octave)
if ~silent
  disp('****************************************************************************');
  disp('Starting packages and toolboxes:');
end
if isoctave
  if local_loadoctpkg('signal'), definput.keyvals.signal = 1; end
  if local_loadoctpkg('statistics'), definput.keyvals.statistics = 1; end
  if local_loadoctpkg('nan'), definput.keyvals.nan = 1; end
  if local_loadoctpkg('nnet'), definput.keyvals.nnet = 1; end
  if local_loadoctpkg('netcdf'), definput.keyvals.netcdf = 1; end
  if local_loadoctpkg('optim'), definput.keyvals.optim = 1; end

  if ~silent
    if definput.keyvals.signal
       disp('* Signal package: loaded.');
    else
       disp('* Signal package: NOT loaded. Install this package and then re-run amt_start.');
    end
    if definput.keyvals.statistics
       disp('* Statistics package: loaded.');
    else
       disp('* Statistics package: NOT loaded. Install this package and then re-run amt_start.');
    end
    if definput.keyvals.nan
       disp('* Nan package: loaded.');
    else
       disp('* Nan package: NOT loaded. Install this package and then re-run amt_start.');
    end
    if definput.keyvals.nnet
       disp('* Neural Network package: loaded.');
    else
       disp('* Neural Network package: NOT loaded. Install this package and then re-run amt_start.');
    end
    if definput.keyvals.netcdf
       disp('* Netcdf package: loaded.');
    else
       disp('* Netcdf package: NOT loaded. Install this package and then re-run amt_start.');
    end
    if definput.keyvals.optim
       disp('* Optimization package: loaded.');
    else
       disp('* Optimization package: NOT loaded. Install this package and then re-run amt_start.');
    end
  end

else % is matlab
  installedToolboxes = ver;
  for ii = 1:numel(installedToolboxes)
      if strcmp(installedToolboxes(ii).Name, 'Signal Processing Toolbox')
          if ~silent, disp('* Signal Processing Toolbox: Found.'); end
          definput.keyvals.signal = 1;
      elseif strcmp(installedToolboxes(ii).Name, 'Statistics and Machine Learning Toolbox')
          if ~silent, disp('* Statistics and Machine Learning Toolbox: Found.'); end
          definput.keyvals.statistics = 1;
      elseif strcmp(installedToolboxes(ii).Name, 'Deep Learning Toolbox')
          if ~silent, disp('* Deep Learning Toolbox: Found.'); end
          definput.keyvals.nnet = 1;
      end
  end

  if ~silent
    if ~definput.keyvals.signal, disp('* Signal Processing Toolbox: Not found.'); end
    if ~definput.keyvals.statistics, disp('* Statistics and Machine Learning Toolbox: Not found.'); end
    if ~definput.keyvals.nnet, disp('* Deep Learning Toolbox: Not found.'); end
  end
end % if isoctave

%% check for the Python environment
pythoncmd='python';
[status ,result]=(system([pythoncmd ' --version']));
if status==0
  definput.keyvals.pythoncmd = pythoncmd;
  definput.keyvals.python=strtrim(result);
  if ~silent, disp(['* Python Environment: ' strtrim(result) '.']); end
else
  pythoncmd='python3';
  [status ,result]=(system([pythoncmd ' --version']));
  if status==0
    definput.keyvals.pythoncmd = pythoncmd;
    definput.keyvals.python=strtrim(result);
    if ~silent, disp(['* Python Environment: ' strtrim(result) '.']); end
  else
    if ~silent, disp('* Python Environment: Not available.'); end
  end
end

%% Starting the LTFAT
if silent
  S = evalc([ltfattarget '(''nojava'',0);']);
else
  S = evalc([ltfattarget '(''nojava'');']);
  disp(['* LTFAT: ' S(1:min([find(S==10) length(S)+1])-1)]);
end
if debug, disp(S); end

definput.keyvals.ltfatfound = ltfatpath;
definput.keyvals.ltfatrunning = 1;

%% Starting the SOFA Toolbox
if ~isempty(sofapath)
  S = evalc('SOFAstart(''restart'');');
  if debug
    disp(S);
  else
    if ~silent, disp(['* SOFA: ' S(1:min([find(S==10) length(S)+1])-1)]); end
  end

  SOFAdbPath(fullfile(basepath,'hrtf'));
  SOFAdbURL(definput.keyvals.hrtfURL);
  warning('off','SOFA:upgrade'); % disable warning on upgrading older SOFA files
  warning('off','SOFA:load'); % disable warnings on loading SOFA files
  definput.keyvals.sofarunning = 1;
  definput.keyvals.sofafound = sofapath;
else
  definput.keyvals.sofarunning = 0;
  definput.keyvals.sofafound = 'NO';
  if ~silent, disp('* SOFA: Toolbox NOT available. No SOFA support, limited HRTF support only. Run amt_start(''install''); to change that.');  end
end

%% Starting the SFS Toolbox
if ~isempty(sfspath)
  S = evalc('SFS_start');
  s=SFS_version;
  if ~isempty(S)
    if ~silent, disp(['* SFS: ' S(1:min([find(S==10) length(S)+1])-1)]); end
  else
    if ~silent
      disp(['* SFS: Toolbox version ' s ' loaded']);
        if isoctave, warning('off','Octave:num-to-str'); end %Octave only: turn off warning about sfs info display
    end
  end
    % check required version
  s_r='2.5.0'; % Required version
  v=sscanf(s,'%d.%d.%d'); v(4)=0;
  v_r=sscanf(s_r,'%d.%d.%d');
  if ~(v(1)>v_r(1) || (v(1)>=v_r(1) && v(2)>v_r(2)) || (v(1)>=v_r(1) && v(2)>=v_r(2) && v(3)>=v_r(3)) ),
      error(['You need SFS >= ' s_r ' to work with AMT. ' ...
        'Please update your package from https://github.com/sfstoolbox/sfs ']);
  end
  definput.keyvals.sfsrunning = 1;
  definput.keyvals.sfsfound = sfspath;
else
  definput.keyvals.sfsrunning = 0;
  definput.keyvals.sfsfound = 'NO';
  if ~silent, disp('* SFS: SFS Toolbox NOT available. Run amt_start(''install''); to change that.');  end
end

%% Starting the Circular Statistics Toolbox
if ~isempty(circstatpath)
  definput.keyvals.circstatrunning = 1;
  definput.keyvals.circstatfound = circstatpath;
  if ~silent, disp('* CIRCSTAT: Circular statistics toolbox found.'); end
else
  definput.keyvals.circstatrunning = 0;
  definput.keyvals.circstatfound = 'NO';
  if ~silent, disp('* CIRCSTAT: Circular statistics toolbox NOT available. Run amt_start(''install''); to change that.'); end
end

%% Starting BinauralSH
if ~isempty(binauralshpath)
  S = evalc('binauralSH_start');
  if debug
    disp(S);
  elseif isempty(S)
    if ~silent, disp('* BINAURALSH: BinauralSH toolbox loaded.'); end
  else
    if ~silent, disp(['* BINAURALSH: ' S(1:min([find(S==10) length(S)+1])-1)]); end
  end
  definput.keyvals.binshrunning = 1;
  definput.keyvals.binshfound = binauralshpath;
  if ~silent
      if isoctave
        warning('off','Octave:num-to-str');%Octave only: turn off warning about sfs info display
      end
  end
else
  definput.keyvals.binshrunning = 0;
  definput.keyvals.binshfound = 'NO';
  if ~silent, disp('* BINAURALSH: BinauralSH toolbox NOT available. Run amt_start(''install''); to change that.'); end
end

%% Starting the BADS Toolbox
if ~isempty(badspath)
  definput.keyvals.badsrunning = 1;
  definput.keyvals.badsfound = badspath;
  if ~silent, disp('* BADS: Bayesian Adaptive Direct Search toolbox found.'); end
else
  definput.keyvals.badsrunning = 0;
  definput.keyvals.badsfound = 'NO';
  if ~silent, disp('* BADS: Bayesian Adaptive Direct Search toolbox NOT available. Run amt_start(''install''); to change that.'); end
end

%% % save the current configuration
amt_configuration(definput); % save the current configuration

%% Compile binaries on install
if install
    try
      status = amt_mex;
    catch ME
      status = 1;
    end
end

%% save the cache and disp flags
cacheFlag = 'normal';
if any(strcmp(varargin, 'redo'))
    cacheFlag = 'redo';
elseif any(strcmp(varargin, 'localonly'))
    cacheFlag = 'localonly';
elseif any(strcmp(varargin, 'cached'))
    cacheFlag = 'cached';
elseif documentation
    cacheFlag = 'redo';
end
[flags,~]=amt_configuration(dispFlag, cacheFlag);

%% Display the internal configuration
if ~silent
  disp(' ');
  disp('****************************************************************************');
  disp(' ');
  disp('Internal configuration:');
  disp('  ');
  disp(['  Auxiliary data (local): ' definput.keyvals.auxdataPath]);
  disp(['  Auxiliary data (web): ' definput.keyvals.auxdataURL]);

  switch flags.cachemode
    case 'normal'
      disp('  Cache mode: Download precalculated results. Examples:');
      disp('              exp_model(...)        shows precalculated results');
      disp('              exp_model(...,''redo'') enforces recalculation');
    case 'localonly'
      disp('  Cache mode: Use local cache or recalculate. Do not connect to remote cache.');
    case 'cached'
      disp('  Cache mode: Use cache or throw error. Do not recalcalculate.');
    case 'redo'
      disp('  Cache mode: Recalculate always. Be patient!');
  end
  disp(' ');
  disp('  Check your configuration via [flags, keyvalues] = amt_configuration().');
  disp(' ');
  disp('The AMT is released under multiple licenses, with the GPL v3 being the primary one.');
  disp('  For models NOT licensed under the GPL3, the corresponding license ');
  disp('  is displayed on the first run.');
  disp(' ');
  disp('Type "help amt_start" for more details...');
end

%% If errors on compilation, display now
if install
    if status > 0
      disp(' ');
      warning('There were errors on calling amt_mex. Scroll up and check the messages.');
    end
end



%% LOCAL FUNCTIONS
function filepath = local_loadtoolbox(toolboxname, targetfile, installationpath)
%Load a thirdparty toolbox to the AMT if locally available

if exist(targetfile,'file')
  filepath = fileparts(which(targetfile));  % file available, nothing to do here.
else
  if exist('OCTAVE_VERSION','builtin')
	filepath = rfsearch (installationpath, targetfile, 2);
	if ~isempty(filepath), filepath = fullfile(installationpath,fileparts(filepath)); end
  else
    filepath = dir(fullfile(installationpath, '**', targetfile)); %check if targetfile exists somewhere
    if ~isempty(filepath), filepath = filepath.folder; end
  end
  if ~isempty(filepath) %if found, great, let's add it to the path
    disp(['* Searching for ' upper(toolboxname) ' toolbox:']);
    disp(['    Package found in ' filepath '.']);
    disp('    Path added to the search path for later.');
    addpath(filepath);
    savepath;
  else
    filepath = []; % report not loaded
  end
end

function filepath = local_installtoolbox(toolboxname, targetfile, downloadpath, installationpath)
%this is a helper function to install a thirdparty toolbox to the AMT.

disp(['* Searching for ' upper(toolboxname) ' toolbox:']);
disp('    Package is neither in the search path nor was it found in the thirdparty folder.');
disp('    Downloading...');
%download from the path in the configuration
downloadTarget = installationpath;
webfn = downloadpath;
archiveName = sprintf('%sZIP',toolboxname);
tokenfn = fullfile(downloadTarget, archiveName);
if ~exist(downloadTarget, 'dir'), mkdir(downloadTarget); end

if exist('OCTAVE_VERSION','builtin')
  [~, stat]=urlwrite(webfn, tokenfn);
else
  if verLessThan('matlab','9.2')
      options = weboptions('Timeout',1000);
      outfilename = websave(tokenfn,webfn);
  else
      o = weboptions();
      certificateFile = o.CertificateFilename; % was here before 1.2.1-dev
      %options = weboptions('Timeout',100, 'CertificateFilename','');
      options = weboptions('CertificateFilename','');  % was here before 1.2.1-dev
      options=weboptions; options.CertificateFilename=(''); % PM for 1.2.1-dev
      outfilename = websave(tokenfn,webfn,options); % PM for 1.2.1-dev
  end
  if exist(outfilename, 'file')
      stat = 1;
  end
end

if ~stat
  warning(['Unable to download file from remote: ' webfn]);
  disp('    Please check your internet settings.');
else
  disp('    Unzipping...');
  unzip(fullfile(installationpath, archiveName), fullfile(installationpath,toolboxname));
  if exist(fullfile(installationpath, [archiveName, '.zip']),'file')
    delete(sprintf('%s',fullfile(installationpath, [archiveName, '.zip'])));
  elseif exist(fullfile(installationpath, archiveName),'file')
    delete(sprintf('%s',fullfile(installationpath, archiveName)));
  end
end

%now, check again if the targetfile can be found
if exist('OCTAVE_VERSION','builtin')
  filepath = rfsearch (installationpath, targetfile, 2);
  if ~isempty(filepath), filepath = fullfile(installationpath,fileparts(filepath)); end
else
  filepath = dir(fullfile(installationpath, toolboxname, '**', targetfile));
  if ~isempty(filepath), filepath = filepath.folder; end
end

if ~isempty(filepath)     %if the targetfile can be found now...
  addpath(filepath);
  savepath;
  disp(['    Installation was successful, it resides within the thirdparty directory.' char(10) ...
        '    The path to the toolbox has been added to the search path for later.']);
else
  error(['    ' toolboxname ' installation was NOT successful. If you did not get a download warning, ' char(10) ...
         '    a ZIP file may still reside within the thirdparty directory. Unzip it and restart the AMT. ' char(10) ...
         '    If not, check your internet settings and/or copy the toolbox manually to thirdparty.' char(10) ...
         '    Then restart the AMT.']);
end

function loaded = local_loadoctpkg(pkgname)
% Loads an Octave package, if not loaded
% Returns 0 if not installed or not being able to load
loaded = 0;
info=pkg('list'); % return all packages (user, system)
for ii = 1:numel(info)
  if strcmp(pkgname, info{ii}.name)
    if ~info{ii}.loaded
      try
        eval(sprintf('pkg load %s', pkgname));
        loaded = 1;
      catch
        loaded = 0;
      end
    else
      loaded = 1;
    end
  end
end




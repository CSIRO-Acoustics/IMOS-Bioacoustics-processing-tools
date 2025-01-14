function varargout = startBASOOP(varargin)
% STARTBASOOP MATLAB code for startBASOOP.fig
%      STARTBASOOP, by itself, creates a new STARTBASOOP or raises the existing
%      singleton*.
%
%      H = STARTBASOOP returns the handle to a new STARTBASOOP or the handle to
%      the existing singleton*.
%
%      STARTBASOOP('CALLBACK',hObject,eventData,handles,...) calls the local
%      function named CALLBACK in STARTBASOOP.M with the given input arguments.
%
%      STARTBASOOP('Property','Value',...) creates a new STARTBASOOP or raises the
%      existing singleton*.  Starting from the left, property value pairs are
%      applied to the GUI before startBASOOP_OpeningFcn gets called.  An
%      unrecognized property name or invalid value makes property application
%      stop.  All inputs are passed to startBASOOP_OpeningFcn via varargin.
%
%      *See GUI Options on GUIDE's Tools menu.  Choose "GUI allows only one
%      instance to run (singleton)".
%
% See also: GUIDE, GUIDATA, GUIHANDLES

% Edit the above text to modify the response to help startBASOOP

% Last Modified by GUIDE v2.5 18-Jun-2018 10:15:47

% Begin initialization code - DO NOT EDIT
gui_Singleton = 1;
gui_State = struct('gui_Name',       mfilename, ...
                   'gui_Singleton',  gui_Singleton, ...
                   'gui_OpeningFcn', @startBASOOP_OpeningFcn, ...
                   'gui_OutputFcn',  @startBASOOP_OutputFcn, ...
                   'gui_LayoutFcn',  [] , ...
                   'gui_Callback',   []);
if nargin && ischar(varargin{1})
    gui_State.gui_Callback = str2func(varargin{1});
end

if nargout
    [varargout{1:nargout}] = gui_mainfcn(gui_State, varargin{:});
else
    gui_mainfcn(gui_State, varargin{:});
end
% End initialization code - DO NOT EDIT


% --- Executes just before startBASOOP is made visible.
function startBASOOP_OpeningFcn(hObject, eventdata, handles, varargin)
% This function has no output args, see OutputFcn.
% hObject    handle to figure
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
% varargin   command line arguments to startBASOOP (see VARARGIN)

% Choose default command line output for startBASOOP
handles.output = hObject;

% Update handles structure
guidata(hObject, handles);

% UIWAIT makes startBASOOP wait for user response (see UIRESUME)
% uiwait(handles.figure1);


% --- Outputs from this function are returned to the command line.
function varargout = startBASOOP_OutputFcn(hObject, eventdata, handles) 
% varargout  cell array for returning output args (see VARARGOUT);
% hObject    handle to figure
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Get default command line output from handles structure
varargout{1} = handles.output;


% --- Executes on button press in BASOOP_Processing.
function BASOOP_Processing_Callback(hObject, eventdata, handles)
% hObject    handle to BASOOP_Processing (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
BASOOP_GUI('?', 'Echoview');

% --- Executes on button press in Final_Package.
function Final_Package_Callback(hObject, eventdata, handles)
% hObject    handle to Final_Package (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
BASOOP_GUI('?', 'NetCDF');






% handles    structure with handles and user data (see GUIDATA)


% --- Executes on button press in Launch_Dataview.
function Launch_Dataview_Callback(hObject, eventdata, handles)
% hObject    handle to Launch_Dataview (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)




% --- Executes on button press in Launch_GUI.
function Launch_GUI_Callback(hObject, eventdata, handles)
% hObject    handle to Launch_GUI (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
GUI

% --- Executes on button press in Help.
function Help_Callback(hObject, eventdata, handles)
% hObject    handle to Help (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
  winopen('Q:\IMOS_BASOOP\IMOS processing.docx')

% --- Executes on button press in LaunchDataview.
function LaunchDataview_Callback(hObject, eventdata, handles)
% hObject    handle to LaunchDataview (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

system('javaw.exe -jar -Xmx1200m Q:\Software\java\dataview\basoop.jar');

% --- Executes on button press in close.
function close_Callback(hObject, eventdata, handles)
% hObject    handle to close (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
close

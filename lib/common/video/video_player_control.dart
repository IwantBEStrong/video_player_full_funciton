import 'dart:async';

import 'package:auto_orientation/auto_orientation.dart';
import 'package:common_utils/common_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';

import 'controller_widget.dart';
import 'video_player_slider.dart';

class VideoPlayerControl extends StatefulWidget {
  VideoPlayerControl({
    Key key,
  }) : super(key: key);

  @override
  VideoPlayerControlState createState() => VideoPlayerControlState();
}

class VideoPlayerControlState extends State<VideoPlayerControl> {
  VideoPlayerController get controller => ControllerWidget.of(context).controller;
  bool get videoInit => ControllerWidget.of(context).videoInit;
  String get title=>ControllerWidget.of(context).title;
  // 记录video播放进度
  Duration _position = Duration(seconds: 0);
  Duration _totalDuration = Duration(seconds: 0);
  Timer _timer; // 计时器，用于延迟隐藏控件ui
  bool _hidePlayControl = true; // 控制是否隐藏控件ui
  double _playControlOpacity = 0; // 通过透明度动画显示/隐藏控件ui
  /// 记录是否全屏
  bool get _isFullScreen =>
      MediaQuery.of(context).orientation == Orientation.landscape;

  @override
  void dispose() {
    super.dispose();
    if (_timer != null) {
      _timer.cancel();
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onDoubleTap: _playOrPause,
      onTap: _togglePlayControl,
      child: Container(
        width: double.infinity,
        height: double.infinity,
        color: Colors.transparent,
        child: WillPopScope(
          child: Offstage(
            offstage: _hidePlayControl,
            child: AnimatedOpacity(
              // 加入透明度动画
              opacity: _playControlOpacity,
              duration: Duration(milliseconds: 300),
              child: Column(
                children: <Widget>[_top(), _middle(), _bottom(context)],
              ),
            ),
          ),
          onWillPop: _onWillPop,
        ),
      ),
    );
  }

  // 拦截返回键
  Future<bool> _onWillPop() async {
    if (_isFullScreen) {
      _toggleFullScreen();
      return false;
    }
    return true;
  }

  // 供父组件调用刷新页面，减少父组件的build
  void setPosition({position, totalDuration}) {
    setState(() {
      _position = position;
      _totalDuration = totalDuration;
    });
  }

  Widget _bottom(BuildContext context) {
    return Container(
      // 底部控件的容器
      width: double.infinity,
      height: 40,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          // 来点黑色到透明的渐变优雅一下
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [Color.fromRGBO(0, 0, 0, .7), Color.fromRGBO(0, 0, 0, .1)],
        ),
      ),
      child: Row(
        // 加载完成时才渲染,flex布局
        children: <Widget>[
          IconButton(
            // 播放按钮
            padding: EdgeInsets.zero,
            iconSize: 26,
            icon: Icon(
              // 根据控制器动态变化播放图标还是暂停
              controller.value.isPlaying ? Icons.pause : Icons.play_arrow,
              color: Colors.white,
            ),
            onPressed: _playOrPause,
          ),
          Expanded(
            // 相当于前端的flex: 1
            child: VideoPlayerSlider(
              startPlayControlTimer: _startPlayControlTimer,
              timer: _timer,
            ),
          ),
          Container(
            // 播放时间
            margin: EdgeInsets.only(left: 10),
            child: Text(
              '${DateUtil.formatDateMs(
                _position?.inMilliseconds,
                format: 'mm:ss',
              )}/${DateUtil.formatDateMs(
                _totalDuration?.inMilliseconds,
                format: 'mm:ss',
              )}',
              style: TextStyle(color: Colors.white),
            ),
          ),
          IconButton(
            // 全屏/横屏按钮
            padding: EdgeInsets.zero,
            iconSize: 26,
            icon: Icon(
              // 根据当前屏幕方向切换图标
              _isFullScreen ? Icons.fullscreen_exit : Icons.fullscreen,
              color: Colors.white,
            ),
            onPressed: () {
              // 点击切换是否全屏
              _toggleFullScreen();
            },
          ),
        ],
      ),
    );
  }

  Widget _middle() {
    return Expanded(
      child: Container(),
    );
  }

  Widget _top() {
    return Container(
      width: double.infinity,
      height: 40,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          // 来点黑色到透明的渐变优雅一下
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [Color.fromRGBO(0, 0, 0, .7), Color.fromRGBO(0, 0, 0, .1)],
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          //在最上层或者不是横屏则隐藏按钮
          ModalRoute.of(context).isFirst && !_isFullScreen
              ? Container()
              : IconButton(
                  icon: Icon(
                    Icons.arrow_back,
                    color: Colors.white,
                  ),
                  onPressed: backPress),
          Text(
            title,
            style: TextStyle(color: Colors.white),
          ),
          //在最上层或者不是横屏则隐藏按钮
          ModalRoute.of(context).isFirst && !_isFullScreen
              ? Container()
              : IconButton(
                  icon: Icon(
                    Icons.arrow_back,
                    color: Colors.transparent,
                  ),
                  onPressed: () {},
                ),
        ],
      ),
    );
  }

  void backPress() {
    print(_isFullScreen);
    // 如果是全屏，点击返回键则关闭全屏，如果不是，则系统返回键
    if (_isFullScreen) {
      _toggleFullScreen();
    } else if(ModalRoute.of(context).isFirst) {
      SystemNavigator.pop();
    }else{
      Navigator.pop(context);
    }
  }

  void _playOrPause() {
    /// 同样的，点击动态播放或者暂停
    if (videoInit) {
      controller.value.isPlaying ? controller.pause() : controller.play();
      _startPlayControlTimer(); // 操作控件后，重置延迟隐藏控件的timer
    }
  }

  void _togglePlayControl() {
    setState(() {
      if (_hidePlayControl) {
        /// 如果隐藏则显示
        _hidePlayControl = false;
        _playControlOpacity = 1;
        _startPlayControlTimer(); // 开始计时器，计时后隐藏
      } else {
        /// 如果显示就隐藏
        if (_timer != null) _timer.cancel(); // 有计时器先移除计时器
        _playControlOpacity = 0;
        Future.delayed(Duration(milliseconds: 500)).whenComplete(() {
          _hidePlayControl = true; // 延迟500ms(透明度动画结束)后，隐藏
        });
      }
    });
  }

  void _startPlayControlTimer() {
    /// 计时器，用法和前端js的大同小异
    if (_timer != null) _timer.cancel();
    _timer = Timer(Duration(seconds: 3), () {
      /// 延迟3s后隐藏
      setState(() {
        _playControlOpacity = 0;
        Future.delayed(Duration(milliseconds: 500)).whenComplete(() {
          _hidePlayControl = true;
        });
      });
    });
  }

  void _toggleFullScreen() {
    setState(() {
      if (_isFullScreen) {
        /// 如果是全屏就切换竖屏
        AutoOrientation.portraitAutoMode();

        ///显示状态栏，与底部虚拟操作按钮
        SystemChrome.setEnabledSystemUIOverlays(
            [SystemUiOverlay.top, SystemUiOverlay.bottom]);
      } else {
        AutoOrientation.landscapeAutoMode();

        ///关闭状态栏，与底部虚拟操作按钮
        SystemChrome.setEnabledSystemUIOverlays([]);
      }
      _startPlayControlTimer(); // 操作完控件开始计时隐藏
    });
  }
}

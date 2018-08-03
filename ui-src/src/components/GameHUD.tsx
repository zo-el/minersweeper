import * as React from 'react';
import './GameHUD.css';

import Chatbox from './Chatbox';


class GameHUD extends React.Component<any, {}> {

  public render() {
    return <div className="game-hud">
      <div className="game-leaderboard">
        {"leaderboard here"}
      </div>
      <div className="game-chat">
        <Chatbox/>
      </div>
    </div>
  }
}

export default GameHUD;

//
//  AudioPlayerLyricsTemplate.swift
//  NuguAgents
//
//  Created by jin kim on 2020/03/13.
//  Copyright © 2020 SK Telecom Co., Ltd. All rights reserved.
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
//

public struct AudioPlayerLyricsTemplate: Decodable {
   public let title: String
   public let lyricsType: String
   public let lyricsInfoList: [LyricsInfo]
   public let showButton: ShowButton?
    
    public struct LyricsInfo: Decodable {
        public let time: Int?
        public let text: String
    }
    
    public struct ShowButton: Decodable {
        public let text: String
    }
}

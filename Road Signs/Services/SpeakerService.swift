
import Foundation

import Foundation
import AVFoundation

class SpeakerService: NSObject {
    
    static let shared = SpeakerService()
    
    private let speaker = AVSpeechSynthesizer()
    private var queuePhrase = [SpeakerPhrase]()
    
    enum SpeakerPhrase {
        case speedOver(speed: Int)
        case warningSpeed
        case crosswalk
        case mainRoad
        case giveWay
        
        var speakText: String {
            switch self {
            case .speedOver(let speed):
                return "Вы въезжаете в зону дейсвтия знака ограничения скорости \(speed) километров в час!"
            case .warningSpeed:
                return "Вы превышаете допустимую скорость!"
            case .crosswalk:
                return "Вы подъезжаете к пешеходному переходу! Снизьте скорость и будьте осторожны!"
            case .mainRoad:
                return "У вас главная дорога!"
            case .giveWay:
                return "Уступите дорогу!"
            }
        }
    }
    
    private override init() {
        super.init()
        self.speaker.delegate = self
    }
    
    private func speakQueue(phrase: String) -> AVSpeechUtterance {
        let voice = AVSpeechSynthesisVoice(identifier: "com.apple.ttsbundle.Milena-compact")
        let toSay = AVSpeechUtterance(string: phrase)
        toSay.voice = voice
        return toSay
    }
    
    func speak(phrase: SpeakerPhrase) {
        let toSay = speakQueue(phrase: phrase.speakText)
        if queuePhrase.isEmpty {
            speaker.speak(toSay)
        }
        queuePhrase.append(phrase)
    }
}


extension SpeakerService: AVSpeechSynthesizerDelegate {
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        queuePhrase.removeFirst()
        if let phrase = queuePhrase.first {
            speaker.speak(speakQueue(phrase: phrase.speakText))
        }
    }
}

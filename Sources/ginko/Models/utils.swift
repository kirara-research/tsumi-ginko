enum SingleOrArray<T: Codable>: Codable {
    case array([T])
    case single(T)

    static func fromArray(_ arr: [T]) -> SingleOrArray<T> {
        if arr.count == 1 {
            return .single(arr[0])
        } else {
            return .array(arr)
        }
    }

    init(from decoder: any Decoder) throws {
        do {
            let sdec = try decoder.singleValueContainer() 
            self = .single(try sdec.decode(T.self))
        } catch DecodingError.typeMismatch {
            var adec = try decoder.unkeyedContainer()
            var vals = [T]()
            while true {
                do {
                    vals.append(try adec.decode(T.self))
                } catch DecodingError.valueNotFound {
                    break
                }
            }
            self = .array(vals)
        }
    }

    func encode(to encoder: any Encoder) throws {
        switch(self) {
            case .array(let val):
                var coder = encoder.unkeyedContainer()
                try coder.encode(contentsOf: val)
            case .single(let val):
                var coder = encoder.singleValueContainer()
                try coder.encode(val)
        }
    }
}
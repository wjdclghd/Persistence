//
//  NSManagedObjectContext.swift
//  Persistence
//
//  Created by jch on 4/4/26.
//

import Foundation
import CoreData

/*
 테스트에서 자주 사용하는 NSManagedObjectContext 보조 기능입니다.

 Mapper 테스트와 저장소 테스트에서 fetch count 같은 반복 코드를 줄여,
 테스트가 의도한 검증 내용에 더 집중할 수 있도록 돕습니다.
 */
extension NSManagedObjectContext {
    /*
     지정한 fetch request의 결과 개수를 반환합니다.

     Parameters:
     - request: 개수를 확인할 fetch request

     Returns:
     - 현재 context에 저장된 matching object 개수

     Throws:
     - fetch count 실행에 실패하면 에러를 던집니다.
     */
    func fetchCount<T: NSManagedObject>(for request: NSFetchRequest<T>) throws -> Int {
        try count(for: request)
    }
}
